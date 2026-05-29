import 'dart:html' as html;

class PrintHelper {
  static void printBarcode({
    required String productName,
    required String barcode,
    required String price,
  }) {
    final content = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Barcode - $productName</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Segoe UI', Tahoma, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
    .label { border: 2px dashed #ccc; padding: 20px 30px; text-align: center; width: 300px; }
    .product-name { font-size: 14px; font-weight: 600; margin-bottom: 10px; }
    .barcode { font-family: 'Libre Barcode 128', monospace; font-size: 48px; letter-spacing: 2px; margin: 10px 0; }
    .barcode-text { font-family: monospace; font-size: 12px; color: #333; margin-bottom: 8px; }
    .price { font-size: 16px; font-weight: 700; }
    @media print {
      body { margin: 0; }
      .label { border: none; }
    }
  </style>
  <link href="https://fonts.googleapis.com/css2?family=Libre+Barcode+128&display=swap" rel="stylesheet">
</head>
<body>
  <div class="label">
    <div class="product-name">$productName</div>
    <div class="barcode">$barcode</div>
    <div class="barcode-text">$barcode</div>
    <div class="price">EGP $price</div>
  </div>
  <script>window.onload = function() { setTimeout(function() { window.print(); }, 500); }</script>
</body>
</html>
''';

    final blob = html.Blob([content], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }
}

void printReportHtml({required String title, required String tableHtml}) {
  final now = DateTime.now();
  final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  final content = '''
<!DOCTYPE html>
<html dir="rtl">
<head>
  <meta charset="UTF-8">
  <title>$title</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Segoe UI', Tahoma, sans-serif; padding: 10px 15px; color: #000; font-size: 11px; }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #000; padding-bottom: 8px; margin-bottom: 10px; }
    .header h1 { font-size: 14px; color: #000; }
    .header .meta { font-size: 9px; color: #333; text-align: right; }
    .header .meta p { margin: 1px 0; }
    table { width: 100%; border-collapse: collapse; margin-top: 6px; font-size: 10px; }
    th { background: #eee; color: #000; font-weight: 600; padding: 4px 6px; border: 1px solid #999; text-align: left; }
    td { padding: 3px 6px; border: 1px solid #ccc; }
    tr:nth-child(even) { background: #f5f5f5; }
    .footer { margin-top: 15px; padding-top: 8px; border-top: 1px solid #999; font-size: 8px; color: #666; text-align: center; }
    .section-title { font-size: 11px; font-weight: 600; margin: 10px 0 4px; color: #000; border-left: 2px solid #000; padding-left: 6px; }
    @media print {
      body { padding: 5px 10px; }
      .no-print { display: none; }
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>$title</h1>
    <div class="meta">
      <p><strong>Ceramic Showroom ERP</strong></p>
      <p>$dateStr</p>
    </div>
  </div>
  $tableHtml
  <div class="footer">Ceramic Showroom ERP &mdash; $dateStr</div>
  <script>window.onload = function() { window.print(); }</script>
</body>
</html>
''';

  final blob = html.Blob([content], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}

String buildTableHtml({
  required List<String> headers,
  required List<List<String>> rows,
  String? sectionTitle,
}) {
  final buffer = StringBuffer();
  if (sectionTitle != null) {
    buffer.write('<p class="section-title">$sectionTitle</p>');
  }
  buffer.write('<table><thead><tr>');
  for (final h in headers) {
    buffer.write('<th>$h</th>');
  }
  buffer.write('</tr></thead><tbody>');
  for (final row in rows) {
    buffer.write('<tr>');
    for (final cell in row) {
      buffer.write('<td>$cell</td>');
    }
    buffer.write('</tr>');
  }
  buffer.write('</tbody></table>');
  return buffer.toString();
}
