class PrintHelper {
  static void printBarcode({
    required String productName,
    required String barcode,
    required String price,
  }) {
    // Printing is only supported on web platform
  }
}

void printReportHtml({required String title, required String tableHtml}) {
  // Printing is only supported on web platform
}

String buildTableHtml({
  required List<String> headers,
  required List<List<String>> rows,
  String? sectionTitle,
}) {
  return '';
}
