// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

class ReportPrintService {
  static Future<bool> printHtml({
    required String title,
    required String htmlBody,
    bool autoClose = false,
    bool autoPrint = false,
  }) async {
    final safeTitle = _escapeHtml(title);
    final autoPrintScript = autoPrint
        ? (autoClose
            ? "window.print();setTimeout(function(){window.close();},900);"
            : "window.print();")
        : "";
    final content = '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>$safeTitle</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 20px; color: #111; }
      .toolbar { position: sticky; top: 0; z-index: 10; background: #fff; border: 1px solid #ddd; border-radius: 10px; padding: 10px 12px; margin-bottom: 14px; display: flex; gap: 10px; align-items: center; }
      .btn { border: 1px solid #0f766e; background: #0f766e; color: #fff; border-radius: 8px; padding: 8px 12px; font-weight: 700; cursor: pointer; }
      .btn.secondary { background: #fff; color: #0f766e; }
      h1, h2, h3 { margin: 0 0 10px 0; }
      .muted { color: #666; font-size: 12px; margin-bottom: 12px; }
      pre { background: #f5f5f5; border: 1px solid #ddd; padding: 12px; white-space: pre-wrap; word-wrap: break-word; }
      table { border-collapse: collapse; width: 100%; margin: 8px 0 14px 0; }
      th, td { border: 1px solid #ddd; padding: 8px; text-align: left; font-size: 12px; }
      th { background: #f0f0f0; }
      @media print {
        .toolbar { display: none; }
        body { margin: 10mm; }
      }
    </style>
  </head>
  <body>
    <div class="toolbar">
      <button class="btn" onclick="window.print()">Imprimir / Guardar PDF</button>
      <button class="btn secondary" onclick="window.close()">Cerrar</button>
      <span class="muted">Vista previa de impresión</span>
    </div>
    $htmlBody
    <script>
      (function() {
        ${autoPrintScript.isEmpty ? '' : autoPrintScript}
      })();
    </script>
  </body>
</html>
''';

    final blob = html.Blob(<String>[content], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    unawaited(
      Future<void>.delayed(
        const Duration(minutes: 1),
        () => html.Url.revokeObjectUrl(url),
      ),
    );
    return true;
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
