// lib/core/network/api_client.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/api_constants.dart';
import '../exceptions/api_exception.dart';

class ApiClient {
  final String? baseUrl;
  final http.Client? client;
  String? _authToken;

  ApiClient({
    this.baseUrl,
    this.client,
  });

  // Helper to get the actual base URL
  String get _baseUrl => baseUrl ?? ApiConstants.baseUrl;

  // Set auth token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  // Get headers with optional auth
  Map<String, String> _getHeaders({
    Map<String, String>? headers,
    bool requireAuth = true,
  }) {
    final defaultHeaders = requireAuth && _authToken != null
        ? ApiConstants.headersWithAuth(_authToken!)
        : ApiConstants.headers;

    return headers != null ? {...defaultHeaders, ...headers} : defaultHeaders;
  }

  // Build URI with query parameters
  Uri _buildUri(String endpoint, {Map<String, dynamic>? queryParameters}) {
    final url = '$_baseUrl$endpoint';
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return Uri.parse(url).replace(
          queryParameters: queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      ));
    }
    return Uri.parse(url);
  }

  // Handle response - can return Map or List
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw ApiException(
          message: 'Failed to parse response',
          statusCode: response.statusCode,
        );
      }
    } else {
      String errorMessage = 'Request failed';
      dynamic errorData;
      try {
        errorData = jsonDecode(response.body);
        errorMessage =
            errorData['message'] ?? errorData['error'] ?? errorMessage;
      } catch (_) {
        errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
      }

      throw ApiException(
        message: errorMessage,
        statusCode: response.statusCode,
        data: errorData,
      );
    }
  }

  // GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters: queryParameters);
      final httpClient = client ?? http.Client();

      final response = await httpClient.get(
        uri,
        headers: _getHeaders(headers: headers, requireAuth: requireAuth),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }

  // POST request
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final httpClient = client ?? http.Client();

      final response = await httpClient.post(
        uri,
        headers: _getHeaders(headers: headers, requireAuth: requireAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }

  // PUT request
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final httpClient = client ?? http.Client();

      final response = await httpClient.put(
        uri,
        headers: _getHeaders(headers: headers, requireAuth: requireAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }

  // PATCH request
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final httpClient = client ?? http.Client();

      final response = await httpClient.patch(
        uri,
        headers: _getHeaders(headers: headers, requireAuth: requireAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }

  // DELETE request
  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final httpClient = client ?? http.Client();

      final response = await httpClient.delete(
        uri,
        headers: _getHeaders(headers: headers, requireAuth: requireAuth),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }

  // POST multipart request for file uploads
  Future<dynamic> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    Map<String, File>? files,
    Map<String, String>? fileNames,
    Map<String, Map<String, dynamic>>? fileBytes,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final httpClient = client ?? http.Client();

      final request = http.MultipartRequest('POST', uri);

      // Add headers (excluding Content-Type for multipart)
      final headers = _getHeaders(requireAuth: requireAuth);
      headers.remove('Content-Type'); // Let multipart set it
      request.headers.addAll(headers);

      // Add fields
      request.fields.addAll(fields);

      // Add files (for mobile/desktop)
      if (files != null && !kIsWeb) {
        for (final entry in files.entries) {
          final file = entry.value;

          // Check if file exists
          if (!await file.exists()) {
            throw ApiException(
              message: 'File does not exist: ${file.path}',
            );
          }

          // Get file length
          final fileLength = await file.length();
          if (fileLength == 0) {
            throw ApiException(
              message: 'File is empty: ${file.path}',
            );
          }

          // Use provided filename if available, otherwise extract from path
          String fileName;
          if (fileNames != null && fileNames.containsKey(entry.key)) {
            fileName = fileNames[entry.key]!;
          } else {
            fileName = file.path.split('/').last;
            // If filename doesn't have extension, try to detect from path
            if (!fileName.contains('.')) {
              final pathParts = file.path.split('.');
              if (pathParts.length > 1) {
                fileName =
                    '${pathParts[pathParts.length - 2]}.${pathParts.last}';
              } else {
                // Default to jpg for images
                fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
              }
            }
          }

          // Ensure filename is not empty
          if (fileName.isEmpty) {
            fileName = 'file_${DateTime.now().millisecondsSinceEpoch}';
          }

          // Determine content type from file extension (same as web)
          String? contentType;
          final lowerFileName = fileName.toLowerCase();
          if (lowerFileName.endsWith('.pdf')) {
            contentType = 'application/pdf';
          } else if (lowerFileName.endsWith('.jpg') ||
              lowerFileName.endsWith('.jpeg')) {
            contentType = 'image/jpeg';
          } else if (lowerFileName.endsWith('.png')) {
            contentType = 'image/png';
          } else if (lowerFileName.endsWith('.gif')) {
            contentType = 'image/gif';
          } else if (lowerFileName.endsWith('.doc')) {
            contentType = 'application/msword';
          } else if (lowerFileName.endsWith('.docx')) {
            contentType =
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          } else if (lowerFileName.endsWith('.xls')) {
            contentType = 'application/vnd.ms-excel';
          } else if (lowerFileName.endsWith('.xlsx')) {
            contentType =
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          } else if (lowerFileName.endsWith('.txt')) {
            contentType = 'text/plain';
          } else if (lowerFileName.endsWith('.wav')) {
            contentType = 'audio/wav';
          } else if (lowerFileName.endsWith('.mp3')) {
            contentType = 'audio/mpeg';
          } else if (lowerFileName.endsWith('.webm')) {
            contentType = 'audio/webm';
          } else if (lowerFileName.endsWith('.ogg')) {
            contentType = 'audio/ogg';
          } else if (lowerFileName.endsWith('.m4a')) {
            // M4A files use audio/mp4 MIME type (MPEG-4 Audio)
            // This is the standard MIME type that Laravel's mimes validation recognizes
            contentType = 'audio/mp4';
          }

          // Read file as bytes to ensure it's fully loaded
          final fileDataBytes = await file.readAsBytes();
          final fileStream = http.ByteStream.fromBytes(fileDataBytes);

          final multipartFile = http.MultipartFile(
            entry.key,
            fileStream,
            fileDataBytes.length,
            filename: fileName,
            contentType:
                contentType != null ? http.MediaType.parse(contentType) : null,
          );

          print('[ApiClient] 📤 Uploading file: $fileName');
          print('[ApiClient] 📤 Content-Type: ${contentType ?? "auto-detect"}');
          final fileSizeMB =
              (fileDataBytes.length / 1024 / 1024).toStringAsFixed(2);
          print(
              '[ApiClient] 📤 File size: $fileSizeMB MB (${fileDataBytes.length} bytes)');
          request.files.add(multipartFile);
        }
      }

      // Add file bytes (for web)
      if (fileBytes != null && kIsWeb) {
        for (final entry in fileBytes.entries) {
          final fileData = entry.value;

          final bytes = fileData['bytes'];
          final fileName = fileData['filename'];

          if (bytes == null || fileName == null) {
            continue;
          }

          if (bytes is! Uint8List || bytes.isEmpty) {
            continue;
          }

          // Determine content type from file extension
          String? contentType;
          final lowerFileName = fileName.toString().toLowerCase();
          if (lowerFileName.endsWith('.pdf')) {
            contentType = 'application/pdf';
          } else if (lowerFileName.endsWith('.jpg') ||
              lowerFileName.endsWith('.jpeg')) {
            contentType = 'image/jpeg';
          } else if (lowerFileName.endsWith('.png')) {
            contentType = 'image/png';
          } else if (lowerFileName.endsWith('.doc')) {
            contentType = 'application/msword';
          } else if (lowerFileName.endsWith('.docx')) {
            contentType =
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          } else if (lowerFileName.endsWith('.xls')) {
            contentType = 'application/vnd.ms-excel';
          } else if (lowerFileName.endsWith('.xlsx')) {
            contentType =
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          } else if (lowerFileName.endsWith('.wav')) {
            contentType = 'audio/wav';
          } else if (lowerFileName.endsWith('.mp3')) {
            contentType = 'audio/mpeg';
          } else if (lowerFileName.endsWith('.webm')) {
            contentType = 'audio/webm';
          } else if (lowerFileName.endsWith('.ogg')) {
            contentType = 'audio/ogg';
          } else if (lowerFileName.endsWith('.m4a')) {
            // M4A files use audio/mp4 MIME type (MPEG-4 Audio)
            contentType = 'audio/mp4';
          }

          print('[ApiClient] 📤 Uploading file (web): $fileName');
          print('[ApiClient] 📤 Content-Type: ${contentType ?? "auto-detect"}');
          final webFileSizeMB = (bytes.length / 1024 / 1024).toStringAsFixed(2);
          print(
              '[ApiClient] 📤 File size: $webFileSizeMB MB (${bytes.length} bytes)');

          final multipartFile = http.MultipartFile.fromBytes(
            entry.key,
            bytes,
            filename: fileName.toString(),
            contentType:
                contentType != null ? http.MediaType.parse(contentType) : null,
          );
          request.files.add(multipartFile);
        }
      }

      final streamedResponse = await httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }
}
