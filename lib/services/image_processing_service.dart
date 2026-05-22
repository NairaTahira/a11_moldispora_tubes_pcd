import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'inference_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ImageProcessingService
//
// Pipeline PCD untuk meningkatkan akurasi deteksi jamur (indoor mold):
//
//   RAW frame (320×320 RGB)
//     │
//     ▼
//   [1] Laplacian Sharpening   → mempertegas tepi spora & tekstur koloni
//     │
//     ▼
//   [2] HSV Color Isolation    → isolasi pigmentasi jamur dari warna cat/dinding
//     │
//     ▼
//   [3] CLAHE-like Contrast    → normalisasi kontras area gelap (sudut lembap)
//     │
//     ▼
//   [4] Gaussian Blur (lite)   → kurangi noise kamera sebelum inference
//     │
//     ▼
//   [5] Normalize [0.0, 1.0]  → input tensor untuk YOLOv8
//
// Semua tahap berjalan di background isolate via compute().
// ─────────────────────────────────────────────────────────────────────────────

class ImageProcessingService {
  // ── Public entry point ──────────────────────────────────────────────────────

  /// Jalankan full PCD pipeline di background isolate.
  /// Input: [img.Image] ukuran 320×320 (sudah di-downsample dari YUV).
  /// ✅ NEW: [pcdSettings] untuk customize pipeline parameters
  /// Output: Float32List siap jadi input tensor [1, 320, 320, 3].
  static Future<List<List<List<List<double>>>>> processForInference(
    img.Image image, [
    PcdSettings pcdSettings = const PcdSettings(),
  ]) async {
    final bytes = image.getBytes(order: img.ChannelOrder.rgb);

    final result = await compute(_pipelineIsolate, {
      'bytes': bytes,
      'width': image.width,
      'height': image.height,
      'sharpening': pcdSettings.sharpening,
      'colorBoost': pcdSettings.colorBoost,
      'contrast': pcdSettings.contrast,
      'blur': pcdSettings.blur,
    });

    return result;
  }

  // ── Isolate entry (top-level dipanggil compute) ──────────────────────────────

  static List<List<List<List<double>>>> _pipelineIsolate(
      Map<String, dynamic> args) {
    final Uint8List bytes = args['bytes'];
    final int width = args['width'];
    final int height = args['height'];
    
    // ✅ NEW: Load settings dari args
    final double sharpening = args['sharpening'] ?? 0.5;
    final double colorBoost = args['colorBoost'] ?? 1.4;
    final double contrast = args['contrast'] ?? 2.5;
    final double blur = args['blur'] ?? 0.8;

    debugPrint('📊 PCD Pipeline started with settings:');
    debugPrint('   sharpening: $sharpening');
    debugPrint('   colorBoost: $colorBoost');
    debugPrint('   contrast: $contrast');
    debugPrint('   blur: $blur');

    // Buat buffer kerja — kita pakai double precision untuk akurasi filter
    var pixels = _bytesToDouble(bytes, width, height); // [H][W][3]

    // ── Tahap 1: Laplacian Sharpening ──────────────────────────────────────
    // ✅ MODIFIED: Use configurable strength
    pixels = _laplacianSharpening(pixels, width, height, strength: sharpening);

    // ── Tahap 2: HSV Color Isolation ───────────────────────────────────────
    // ✅ MODIFIED: Use configurable colorBoost
    pixels = _hsvMoldBoost(pixels, width, height, colorBoost: colorBoost);

    // ── Tahap 3: CLAHE-like Adaptive Contrast ──────────────────────────────
    // ✅ MODIFIED: Use configurable contrast (clip limit)
    pixels = _adaptiveContrast(pixels, width, height,
        tileSize: 8, clipLimit: contrast);

    // ── Tahap 4: Gaussian Blur ───────────────────────────────────────────────
    // ✅ MODIFIED: Use configurable sigma
    pixels = _gaussianBlur3x3(pixels, width, height, sigma: blur);

    // ── Tahap 5: Normalize ke [0.0, 1.0] ───────────────────────────────────
    return _toModelInput(pixels, width, height);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tahap 1 — Laplacian Sharpening
// ─────────────────────────────────────────────────────────────────────────────

/// ✅ MODIFIED: Kernel: [0,-1,0 / -1,5,-1 / 0,-1,0]
/// `strength` (0.0–1.0) mengontrol intensitas penajaman.
/// Di-clamp ke [0,255] setelah penerapan.
List<List<List<double>>> _laplacianSharpening(
    List<List<List<double>>> pixels, int w, int h,
    {double strength = 0.5}) {
  // Kernel sharpening (identity + laplacian)
  const kernel = [
    [0.0, -1.0, 0.0],
    [-1.0, 5.0, -1.0],
    [0.0, -1.0, 0.0],
  ];

  final out = _createBuffer(h, w);

  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      for (int c = 0; c < 3; c++) {
        double sum = 0.0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            sum += kernel[ky + 1][kx + 1] * pixels[y + ky][x + kx][c];
          }
        }
        // Blend antara original dan sharpened berdasarkan strength
        final blended = pixels[y][x][c] * (1.0 - strength) + sum * strength;
        out[y][x][c] = blended.clamp(0.0, 255.0);
      }
    }
  }

  // Border pixels: salin langsung (kernel tidak bisa diterapkan di tepi)
  for (int y = 0; y < h; y++) {
    out[y][0] = List.from(pixels[y][0]);
    out[y][w - 1] = List.from(pixels[y][w - 1]);
  }
  for (int x = 0; x < w; x++) {
    out[0][x] = List.from(pixels[0][x]);
    out[h - 1][x] = List.from(pixels[h - 1][x]);
  }

  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tahap 2 — HSV Color Isolation (Mold Boost)
// ─────────────────────────────────────────────────────────────────────────────

/// ✅ MODIFIED: Konversi RGB → HSV, boost saturasi dan value untuk rentang warna khas jamur
/// dengan configurable [colorBoost] multiplier
List<List<List<double>>> _hsvMoldBoost(
    List<List<List<double>>> pixels, int w, int h,
    {double colorBoost = 1.4}) {
  final out = _createBuffer(h, w);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final r = pixels[y][x][0] / 255.0;
      final g = pixels[y][x][1] / 255.0;
      final b = pixels[y][x][2] / 255.0;

      final hsv = _rgbToHsv(r, g, b);
      double hue = hsv[0]; // 0–360
      double sat = hsv[1]; // 0–1
      double val = hsv[2]; // 0–1

      // Deteksi zona warna jamur
      final isMoldGreen = (hue >= 80 && hue <= 160) && sat >= 0.2 && val <= 0.55;
      final isMoldBrown = (hue >= 15 && hue <= 45) && sat >= 0.15 && val <= 0.6;
      final isMoldDark = val <= 0.2 && sat >= 0.1; // hitam/gelap pekat

      if (isMoldGreen || isMoldBrown || isMoldDark) {
        // ✅ MODIFIED: Use configurable colorBoost instead of hardcoded 1.4
        sat = (sat * colorBoost).clamp(0.0, 1.0);
        // Sedikit terangkan value supaya model bisa membaca tekstur
        if (val < 0.15) val = (val + 0.08).clamp(0.0, 1.0);
      } else {
        // Area non-jamur: sedikit desaturasi agar kontras terhadap jamur naik
        sat = (sat * 0.85).clamp(0.0, 1.0);
      }

      final rgb = _hsvToRgb(hue, sat, val);
      out[y][x][0] = (rgb[0] * 255.0).clamp(0.0, 255.0);
      out[y][x][1] = (rgb[1] * 255.0).clamp(0.0, 255.0);
      out[y][x][2] = (rgb[2] * 255.0).clamp(0.0, 255.0);
    }
  }

  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tahap 3 — Adaptive Contrast (CLAHE-like, per-tile)
// ─────────────────────────────────────────────────────────────────────────────

/// ✅ MODIFIED: Bagi gambar menjadi tile, dengan configurable [clipLimit]
List<List<List<double>>> _adaptiveContrast(
    List<List<List<double>>> pixels, int w, int h,
    {int tileSize = 8, double clipLimit = 2.5}) {
  final out = _createBuffer(h, w);
  final numTilesX = (w / tileSize).ceil();
  final numTilesY = (h / tileSize).ceil();

  for (int ty = 0; ty < numTilesY; ty++) {
    for (int tx = 0; tx < numTilesX; tx++) {
      final x0 = tx * tileSize;
      final y0 = ty * tileSize;
      final x1 = math.min(x0 + tileSize, w);
      final y1 = math.min(y0 + tileSize, h);

      // Kumpulkan nilai luminance tile ini (channel Y dari YCbCr)
      final lumValues = <double>[];
      for (int y = y0; y < y1; y++) {
        for (int x = x0; x < x1; x++) {
          final lum = 0.299 * pixels[y][x][0] +
              0.587 * pixels[y][x][1] +
              0.114 * pixels[y][x][2];
          lumValues.add(lum);
        }
      }

      // Histogram 256-bin
      final hist = List<double>.filled(256, 0.0);
      for (final v in lumValues) {
        hist[v.clamp(0, 255).toInt()]++;
      }

      // Clip histogram (CLAHE clip) — ✅ MODIFIED: Use configurable clipLimit
      final clipVal = clipLimit * lumValues.length / 256.0;
      double excess = 0.0;
      for (int i = 0; i < 256; i++) {
        if (hist[i] > clipVal) {
          excess += hist[i] - clipVal;
          hist[i] = clipVal;
        }
      }
      // Distribusikan excess secara merata
      final addPerBin = excess / 256.0;
      for (int i = 0; i < 256; i++) {
        hist[i] += addPerBin;
      }

      // Cumulative distribution function (CDF)
      final cdf = List<double>.filled(256, 0.0);
      cdf[0] = hist[0];
      for (int i = 1; i < 256; i++) {
        cdf[i] = cdf[i - 1] + hist[i];
      }
      final cdfMin = cdf.firstWhere((v) => v > 0, orElse: () => 1.0);
      final total = lumValues.length.toDouble();

      // LUT: luma lama → luma baru
      final lut = List<double>.filled(256, 0.0);
      for (int i = 0; i < 256; i++) {
        lut[i] = ((cdf[i] - cdfMin) / (total - cdfMin) * 255.0).clamp(0.0, 255.0);
      }

      // Terapkan LUT ke setiap pixel di tile
      // Pertahankan hue & saturation, hanya ubah luminance
      for (int y = y0; y < y1; y++) {
        for (int x = x0; x < x1; x++) {
          final r = pixels[y][x][0];
          final g = pixels[y][x][1];
          final b = pixels[y][x][2];
          final oldLum = (0.299 * r + 0.587 * g + 0.114 * b).clamp(0.0, 255.0);
          final newLum = lut[oldLum.toInt()];
          final scale = oldLum > 0 ? newLum / oldLum : 1.0;
          out[y][x][0] = (r * scale).clamp(0.0, 255.0);
          out[y][x][1] = (g * scale).clamp(0.0, 255.0);
          out[y][x][2] = (b * scale).clamp(0.0, 255.0);
        }
      }
    }
  }

  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tahap 4 — Gaussian Blur 3×3
// ─────────────────────────────────────────────────────────────────────────────

/// ✅ MODIFIED: Kernel Gaussian 3×3 dengan configurable [sigma]
List<List<List<double>>> _gaussianBlur3x3(
    List<List<List<double>>> pixels, int w, int h,
    {double sigma = 0.8}) {
  // Hitung kernel 3×3
  final kernel = List.generate(3, (ky) {
    return List.generate(3, (kx) {
      final dx = kx - 1.0;
      final dy = ky - 1.0;
      return math.exp(-(dx * dx + dy * dy) / (2.0 * sigma * sigma));
    });
  });

  // Normalisasi kernel
  double kSum = 0.0;
  for (final row in kernel) {
    for (final v in row) kSum += v;
  }
  for (int ky = 0; ky < 3; ky++) {
    for (int kx = 0; kx < 3; kx++) {
      kernel[ky][kx] /= kSum;
    }
  }

  final out = _createBuffer(h, w);
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      for (int c = 0; c < 3; c++) {
        double sum = 0.0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            sum += kernel[ky + 1][kx + 1] * pixels[y + ky][x + kx][c];
          }
        }
        out[y][x][c] = sum.clamp(0.0, 255.0);
      }
    }
  }

  // Border: salin langsung
  for (int y = 0; y < h; y++) {
    out[y][0] = List.from(pixels[y][0]);
    out[y][w - 1] = List.from(pixels[y][w - 1]);
  }
  for (int x = 0; x < w; x++) {
    out[0][x] = List.from(pixels[0][x]);
    out[h - 1][x] = List.from(pixels[h - 1][x]);
  }

  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tahap 5 — Normalize ke model input tensor
// ─────────────────────────────────────────────────────────────────────────────

/// Output: [1][height][width][3], nilai 0.0–1.0
List<List<List<List<double>>>> _toModelInput(
    List<List<List<double>>> pixels, int w, int h) {
  return [
    List.generate(
      h,
      (y) => List.generate(
        w,
        (x) => [
          pixels[y][x][0] / 255.0,
          pixels[y][x][1] / 255.0,
          pixels[y][x][2] / 255.0,
        ],
      ),
    )
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper utilities
// ─────────────────────────────────────────────────────────────────────────────

List<List<List<double>>> _createBuffer(int h, int w) {
  return List.generate(h, (_) => List.generate(w, (_) => [0.0, 0.0, 0.0]));
}

List<List<List<double>>> _bytesToDouble(Uint8List bytes, int w, int h) {
  return List.generate(h, (y) {
    return List.generate(w, (x) {
      final i = (y * w + x) * 3;
      return [
        bytes[i].toDouble(),
        bytes[i + 1].toDouble(),
        bytes[i + 2].toDouble(),
      ];
    });
  });
}

/// RGB [0.0,1.0] → HSV: H[0–360], S[0–1], V[0–1]
List<double> _rgbToHsv(double r, double g, double b) {
  final maxV = math.max(r, math.max(g, b));
  final minV = math.min(r, math.min(g, b));
  final delta = maxV - minV;

  double h = 0.0;
  if (delta > 0.0001) {
    if (maxV == r) {
      h = 60.0 * (((g - b) / delta) % 6.0);
    } else if (maxV == g) {
      h = 60.0 * (((b - r) / delta) + 2.0);
    } else {
      h = 60.0 * (((r - g) / delta) + 4.0);
    }
  }
  if (h < 0) h += 360.0;

  final s = maxV < 0.0001 ? 0.0 : delta / maxV;
  return [h, s, maxV];
}

/// HSV → RGB [0.0,1.0]
List<double> _hsvToRgb(double h, double s, double v) {
  if (s < 0.0001) return [v, v, v];
  final sector = h / 60.0;
  final i = sector.floor();
  final f = sector - i;
  final p = v * (1.0 - s);
  final q = v * (1.0 - s * f);
  final t = v * (1.0 - s * (1.0 - f));

  switch (i % 6) {
    case 0: return [v, t, p];
    case 1: return [q, v, p];
    case 2: return [p, v, t];
    case 3: return [p, q, v];
    case 4: return [t, p, v];
    default: return [v, p, q];
  }
}