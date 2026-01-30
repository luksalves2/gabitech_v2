import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for Supabase Storage operations
/// Organiza arquivos por gabinete e tipo:
/// - gabinete_{id}/images/
/// - gabinete_{id}/videos/
/// - gabinete_{id}/audios/
/// - gabinete_{id}/documents/
class StorageService {
  static const String _bucketName = 'media';
  
  final SupabaseClient _client;

  StorageService(this._client);

  /// Get the storage bucket
  SupabaseStorageClient get _storage => _client.storage;

  /// Get folder path for a media type
  String _getFolderPath(int gabineteId, String mediaType) {
    final folder = switch (mediaType) {
      'image' => 'images',
      'video' => 'videos',
      'audio' || 'ptt' => 'audios',
      'document' => 'documents',
      _ => 'others',
    };
    return 'gabinete_$gabineteId/$folder';
  }

  /// Generate unique filename
  String _generateFilename(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = originalName.contains('.') 
        ? '.${originalName.split('.').last}'
        : '';
    return '${timestamp}_${originalName.hashCode}$extension';
  }

  /// Upload a file to Supabase Storage
  /// Returns the public URL of the uploaded file
  Future<StorageResponse> uploadFile({
    required int gabineteId,
    required String mediaType,
    required String fileName,
    required Uint8List fileBytes,
    String? contentType,
  }) async {
    try {
      final folderPath = _getFolderPath(gabineteId, mediaType);
      final uniqueFileName = _generateFilename(fileName);
      final filePath = '$folderPath/$uniqueFileName';

      // Upload file
      await _storage.from(_bucketName).uploadBinary(
        filePath,
        fileBytes,
        fileOptions: FileOptions(
          contentType: contentType ?? _getContentType(fileName, mediaType),
          upsert: true,
        ),
      );

      // Get public URL
      final publicUrl = _storage.from(_bucketName).getPublicUrl(filePath);

      return StorageResponse.success(
        url: publicUrl,
        path: filePath,
        fileName: uniqueFileName,
      );
    } catch (e) {
      return StorageResponse.error('Erro ao fazer upload: $e');
    }
  }

  /// Get content type based on file extension
  String _getContentType(String fileName, String mediaType) {
    final ext = fileName.split('.').last.toLowerCase();
    
    // Images
    if (['jpg', 'jpeg'].contains(ext)) return 'image/jpeg';
    if (ext == 'png') return 'image/png';
    if (ext == 'gif') return 'image/gif';
    if (ext == 'webp') return 'image/webp';
    
    // Videos
    if (ext == 'mp4') return 'video/mp4';
    if (ext == 'mov') return 'video/quicktime';
    if (ext == 'avi') return 'video/x-msvideo';
    if (ext == 'webm') return 'video/webm';
    if (ext == 'mkv') return 'video/x-matroska';
    
    // Audio
    if (ext == 'mp3') return 'audio/mpeg';
    if (ext == 'wav') return 'audio/wav';
    if (ext == 'ogg') return 'audio/ogg';
    if (ext == 'm4a') return 'audio/mp4';
    if (ext == 'aac') return 'audio/aac';
    
    // Documents
    if (ext == 'pdf') return 'application/pdf';
    if (ext == 'doc') return 'application/msword';
    if (ext == 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (ext == 'xls') return 'application/vnd.ms-excel';
    if (ext == 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (ext == 'txt') return 'text/plain';
    if (ext == 'csv') return 'text/csv';
    
    // Default based on media type
    return switch (mediaType) {
      'image' => 'image/jpeg',
      'video' => 'video/mp4',
      'audio' || 'ptt' => 'audio/mpeg',
      'document' => 'application/octet-stream',
      _ => 'application/octet-stream',
    };
  }

  /// Delete a file from storage
  Future<bool> deleteFile(String filePath) async {
    try {
      await _storage.from(_bucketName).remove([filePath]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// List files in a folder
  Future<List<FileObject>> listFiles(int gabineteId, String mediaType) async {
    try {
      final folderPath = _getFolderPath(gabineteId, mediaType);
      return await _storage.from(_bucketName).list(path: folderPath);
    } catch (e) {
      return [];
    }
  }

  /// Get storage usage for a gabinete (approximate)
  Future<int> getStorageUsage(int gabineteId) async {
    try {
      int totalBytes = 0;
      
      for (final type in ['image', 'video', 'audio', 'document']) {
        final files = await listFiles(gabineteId, type);
        for (final file in files) {
          totalBytes += file.metadata?['size'] as int? ?? 0;
        }
      }
      
      return totalBytes;
    } catch (e) {
      return 0;
    }
  }
}

/// Response wrapper for storage operations
class StorageResponse {
  final bool isSuccess;
  final String? url;
  final String? path;
  final String? fileName;
  final String? error;

  StorageResponse._({
    required this.isSuccess,
    this.url,
    this.path,
    this.fileName,
    this.error,
  });

  factory StorageResponse.success({
    required String url,
    required String path,
    required String fileName,
  }) {
    return StorageResponse._(
      isSuccess: true,
      url: url,
      path: path,
      fileName: fileName,
    );
  }

  factory StorageResponse.error(String error) {
    return StorageResponse._(
      isSuccess: false,
      error: error,
    );
  }
}
