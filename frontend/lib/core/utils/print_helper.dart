import 'dart:html' as html;

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
    body { font-family: 'Segoe UI', Tahoma, sans-serif; padding: 30px; color: #333; }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 3px solid #1a73e8; padding-bottom: 15px; margin-bottom: 20px; }
    .header h1 { font-size: 22px; color: #1a73e8; }
    .header .meta { font-size: 12px; color: #666; text-align: right; }
    .header .meta p { margin: 2px 0; }
    table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; }
    th { background: #f0f4ff; color: #1a73e8; font-weight: 600; padding: 10px 12px; border: 1px solid #ddd; text-align: left; }
    td { padding: 8px 12px; border: 1px solid #eee; }
    tr:nth-child(even) { background: #fafbff; }
    tr:hover { background: #f0f4ff; }
    .footer { margin-top: 30px; padding-top: 15px; border-top: 1px solid #ddd; font-size: 11px; color: #999; text-align: center; }
    .section-title { font-size: 16px; font-weight: 600; margin: 20px 0 10px; color: #333; border-left: 4px solid #1a73e8; padding-left: 10px; }
    .badge-positive { background: #e6f4ea; color: #1e8e3e; padding: 2px 8px; border-radius: 4px; font-size: 11px; }
    .badge-negative { background: #fce8e6; color: #d93025; padding: 2px 8px; border-radius: 4px; font-size: 11px; }
    @media print {
      body { padding: 15px; }
      .no-print { display: none; }
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>$title</h1>
    <div class="meta">
      <p><strong>Ceramic Showroom ERP</strong></p>
      <p>Generated: $dateStr</p>
    </div>
  </div>
  $tableHtml
  <div class="footer">Ceramic Showroom ERP &mdash; Auto-generated report &mdash; $dateStr</div>
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
