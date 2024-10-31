import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gsheets/gsheets.dart';

final _credentials = '''
{
  "type": "${dotenv.env['GOOGLE_CLOUD_TYPE']}",
  "project_id": "${dotenv.env['GOOGLE_CLOUD_PROJECT_ID']}",
  "private_key_id": "${dotenv.env['GOOGLE_CLOUD_PRIVATE_KEY_ID']}",
  "private_key": "${dotenv.env['GOOGLE_CLOUD_PRIVATE_KEY']}",
  "client_email": "${dotenv.env['GOOGLE_CLOUD_CLIENT_EMAIL']}",
  "client_id": "${dotenv.env['GOOGLE_CLOUD_CLIENT_ID']}",
  "auth_uri": "${dotenv.env['GOOGLE_CLOUD_AUTH_URI']}",
  "token_uri": "${dotenv.env['GOOGLE_CLOUD_TOKEN_URI']}",
  "auth_provider_x509_cert_url": "${dotenv.env['GOOGLE_CLOUD_AUTH_PROVIDER_CERT_URL']}",
  "client_x509_cert_url": "${dotenv.env['GOOGLE_CLOUD_CLIENT_CERT_URL']}"
}
''';

final _spreadsheetId = dotenv.env['SPREADSHEET_ID'];

class GSheetsReaderPage extends StatefulWidget {
  const GSheetsReaderPage({super.key});

  @override
  _GSheetsReaderPageState createState() => _GSheetsReaderPageState();
}

class _GSheetsReaderPageState extends State<GSheetsReaderPage> {
  List<List<String>> _data = [];
  bool _isLoading = false;
  String _error = '';
  final ScrollController _verticalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sheets 讀取器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGoogleSheetData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadGoogleSheetData();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _error,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            ElevatedButton(
              onPressed: _loadGoogleSheetData,
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (_data.isEmpty) {
      return const Center(
        child: Text('無數據'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 表頭行
                        Row(
                          children: List.generate(
                            _data[0].length,
                            (index) => Container(
                              width: 150,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                              ),
                              child: Text(
                                _data[0][index].isEmpty
                                    ? 'Column ${index + 1}'
                                    : _data[0][index],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        // 數據行
                        ...List.generate(
                          _data.length - 1,
                          (rowIndex) => Row(
                            children: List.generate(
                              _data[0].length,
                              (colIndex) => Container(
                                width: 150,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  _data[rowIndex + 1][colIndex],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadGoogleSheetData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final gsheets = GSheets(_credentials);
      final ss = await gsheets.spreadsheet(_spreadsheetId!);
      final sheet = ss.worksheetByIndex(0);

      if (sheet == null) {
        throw Exception('找不到工作表');
      }

      final values = await sheet.values.allRows();
      final normalizedData = _normalizeData(values);

      setState(() {
        _data = normalizedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '讀取數據時發生錯誤: $e';
        _isLoading = false;
      });
    }
  }

  List<List<String>> _normalizeData(List<List<dynamic>> rawData) {
    if (rawData.isEmpty) return [];
    int maxColumns =
        rawData.fold<int>(0, (max, row) => row.length > max ? row.length : max);
    return rawData.map((row) {
      List<String> normalizedRow =
          row.map((cell) => cell?.toString() ?? '').toList();
      while (normalizedRow.length < maxColumns) {
        normalizedRow.add('');
      }
      return normalizedRow;
    }).toList();
  }
}
