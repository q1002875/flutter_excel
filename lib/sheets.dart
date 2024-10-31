import 'dart:io'; // 导入 File

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gsheets/gsheets.dart';
import 'package:image_picker/image_picker.dart'; // 导入 ImagePicker

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
  final TextEditingController _inputController = TextEditingController();
  final ImagePicker _picker = ImagePicker(); // ImagePicker 实例

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sheets 讀取器'),
        leading: IconButton(
          // 使用 leading 属性来添加图标
          icon: const Icon(Icons.image),
          onPressed: _selectImage, // 添加上传图片按钮
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGoogleSheetData,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDataDialog,
          ),
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: _selectImage, // 添加上传图片按钮
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadGoogleSheetData();
  }

  Future<void> _addDataToSheet() async {
    final newRow = _inputController.text.split(',');
    try {
      //認證
      final gsheets = GSheets(_credentials);
      //使用哪一個excel資料
      final ss = await gsheets.spreadsheet(_spreadsheetId!);
      final sheet = ss.worksheetByIndex(0);

      if (sheet == null) {
        throw Exception('找不到工作表');
      }

      await sheet.values.appendRow(newRow);
      _loadGoogleSheetData(); // 重新加载数据以更新显示
    } catch (e) {
      setState(() {
        _error = '寫入數據時發生錯誤: $e';
      });
    }
  }

  Widget _buildBody() {
    // 现有的 _buildBody 实现保持不变
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
                        // 表头行
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
                        // 数据行
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

  // 选择图片
  Future<void> _selectImage() async {
    final pickedFile =
        await _picker.pickImage(source: ImageSource.gallery); // 从图库选择图片
    if (pickedFile != null) {
      await _uploadImageToSheet(File(pickedFile.path)); // 上传图片到工作表
    }
  }

  void _showAddDataDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增數據'),
          content: TextField(
            controller: _inputController,
            decoration: const InputDecoration(hintText: '輸入數據 (逗號分隔)'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                _addDataToSheet();
                Navigator.of(context).pop();
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  // 上传图片到 Google Sheets
  Future<void> _uploadImageToSheet(File image) async {
    // 此处逻辑需要实现将图片转换为可以存入 Google Sheets 的格式
    // 你可以选择上传图片到 Google Drive，然后将文件的链接写入 Google Sheets
    // 这里是一个示例，具体实现取决于你的需求

    try {
      final gsheets = GSheets(_credentials);
      final ss = await gsheets.spreadsheet(_spreadsheetId!);
      final sheet = ss.worksheetByIndex(0);

      if (sheet == null) {
        throw Exception('找不到工作表');
      }

      // 在这里添加将图片上传到 Google Drive 的逻辑，然后获取文件链接

      // 假设你获得了文件链接 fileLink
      const fileLink = 'YOUR_IMAGE_FILE_LINK'; // 替换为实际链接

      // 将文件链接写入工作表的指定行
      await sheet.values.appendRow([fileLink]); // 在工作表中添加文件链接

      _loadGoogleSheetData(); // 重新加载数据以更新显示
    } catch (e) {
      setState(() {
        _error = '上传图片时发生错误: $e';
      });
    }
  }
}
