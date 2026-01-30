import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for UazAPI WhatsApp integration
/// Base URL: https://gabitech.uazapi.com
/// 
/// Headers:
/// - admintoken: Token fixo da conta admin UazAPI
/// - token: Token da instância do gabinete (campo token_zapi)
class UazapiService {
  static const String _baseUrl = 'https://gabitech.uazapi.com';
  
  /// Token fixo da conta admin no UazAPI
  static const String _adminToken = 'FNTW4J6mq5Fiep7wJO4OY1QbXSyTBIOj9HXp3A40DK5caRUKuY';

  final http.Client _client;

  UazapiService({http.Client? client}) : _client = client ?? http.Client();

  /// Headers padrão para todas as requisições
  /// [instanceToken]: token da instância (gabinete.tokenZapi)
  Map<String, String> _headers({String? instanceToken}) {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'admintoken': _adminToken,
    };
    
    if (instanceToken != null) {
      headers['token'] = instanceToken;
    }
    
    return headers;
  }

  // ============================================
  // INSTANCE MANAGEMENT
  // ============================================

  /// Criar uma nova instância do WhatsApp
  /// POST /instance/init
  /// Body: { "nome": "nome_da_instancia" }
  /// Returns: token da instância
  Future<UazapiResponse<String>> criarInstancia({
    required String nome,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/instance/init'),
        headers: _headers(),
        body: jsonEncode({'nome': nome}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = data['instance']?['token'] as String?;
        if (token != null) {
          return UazapiResponse.success(token);
        }
        return UazapiResponse.error('Token não encontrado na resposta');
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao criar instância');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Conectar instância (gera paircode para parear WhatsApp)
  /// POST /instance/connect
  /// Headers: token (instance token)
  /// Body: { "telefone": "5551999999999" }
  /// Returns: paircode para parear
  Future<UazapiResponse<String>> conectarInstancia({
    required String instanceToken,
    required String telefone,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/instance/connect'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({'telefone': telefone}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final paircode = data['instance']?['paircode'] as String?;
        if (paircode != null) {
          return UazapiResponse.success(paircode);
        }
        return UazapiResponse.error('Paircode não encontrado na resposta');
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao conectar instância');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Verificar status da instância
  /// GET /instance/status
  /// Headers: token (instance token)
  /// Returns: status da conexão
  Future<UazapiResponse<InstanceStatus>> statusInstancia(String instanceToken) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/instance/status'),
        headers: _headers(instanceToken: instanceToken),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return UazapiResponse.success(InstanceStatus.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao verificar status');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  // ============================================
  // CHATS
  // ============================================

  /// Buscar chats/conversas
  /// POST /chat/find
  /// Headers: token (instance token)
  /// Body: { "limite": 50 } (opcional)
  /// Returns: lista de chats
  Future<UazapiResponse<List<UazapiChat>>> buscarChats({
    required String instanceToken,
    int? limite,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (limite != null) {
        body['limite'] = limite;
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/find'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        final chats = (data['chats'] as List<dynamic>?)
            ?.map((e) => UazapiChat.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
        return UazapiResponse.success(chats);
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao buscar chats');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Buscar mensagens de um chat
  /// POST /chat/messages
  /// Headers: token (instance token)
  /// Body: { "telefone": "5551999999999", "limite": 50 }
  Future<UazapiResponse<List<UazapiMessage>>> buscarMensagens({
    required String instanceToken,
    required String telefone,
    int? limite,
  }) async {
    try {
      final body = <String, dynamic>{
        'telefone': telefone,
      };
      if (limite != null) {
        body['limite'] = limite;
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/messages'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        final messages = (data['messages'] as List<dynamic>?)
            ?.map((e) => UazapiMessage.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
        return UazapiResponse.success(messages);
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao buscar mensagens');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  // ============================================
  // CONTACTS
  // ============================================

  /// Buscar dados de um contato
  /// POST /contact/info
  /// Headers: token (instance token)
  /// Body: { "telefone": "5551999999999" }
  Future<UazapiResponse<UazapiContact>> dadosContato({
    required String instanceToken,
    required String telefone,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/contact/info'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({'telefone': telefone}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return UazapiResponse.success(UazapiContact.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao buscar contato');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  // ============================================
  // SEND MESSAGES
  // ============================================

  /// Formata número de telefone para o formato WhatsApp
  /// Ex: "5547991935950" -> "5547991935950@s.whatsapp.net"
  String _formatarNumeroWhatsApp(String telefone) {
    // Remove caracteres não numéricos
    final apenasNumeros = telefone.replaceAll(RegExp(r'[^\d]'), '');
    return '$apenasNumeros@s.whatsapp.net';
  }

  /// Enviar mensagem de texto
  /// POST /send/text
  /// Headers: admintoken, token (instance token)
  /// Body: { "number": "5547991935950@s.whatsapp.net", "text": "Mensagem" }
  Future<UazapiResponse<SendMessageResult>> enviarMensagem({
    required String instanceToken,
    required String telefone,
    required String mensagem,
  }) async {
    try {
      final numero = _formatarNumeroWhatsApp(telefone);
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/send/text'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({
          'number': numero,
          'text': mensagem,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(SendMessageResult.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao enviar mensagem');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Marcar mensagens como lidas (sincroniza status com WhatsApp)
  /// POST /message/markread
  /// Body: { "id": ["<id_msg1>", "<id_msg2>"] }
  Future<UazapiResponse<bool>> marcarMensagensComoLidas({
    required String instanceToken,
    required List<String> messageIds,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/message/markread'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({'id': messageIds}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(true);
      }

      final data = jsonDecode(response.body);
      return UazapiResponse.error(data['message'] ?? 'Erro ao marcar mensagens como lidas');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Enviar imagem
  /// POST /send/media
  /// Body: { "number": "5511999999999", "type": "image", "file": "url", "text": "caption" }
  Future<UazapiResponse<SendMessageResult>> enviarImagem({
    required String instanceToken,
    required String telefone,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final numero = _formatarNumeroWhatsApp(telefone);
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/send/media'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({
          'number': numero,
          'type': 'image',
          'file': imageUrl,
          'text': caption ?? '',
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(SendMessageResult.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao enviar imagem');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Enviar vídeo
  /// POST /send/media
  /// Body: { "number": "5511999999999", "type": "video", "file": "url", "text": "caption" }
  Future<UazapiResponse<SendMessageResult>> enviarVideo({
    required String instanceToken,
    required String telefone,
    required String videoUrl,
    String? caption,
  }) async {
    try {
      final numero = _formatarNumeroWhatsApp(telefone);
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/send/media'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({
          'number': numero,
          'type': 'video',
          'file': videoUrl,
          'text': caption ?? '',
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(SendMessageResult.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao enviar vídeo');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Enviar documento
  /// POST /send/media
  /// Body: { "number": "5511999999999", "type": "document", "file": "url", "docName": "nome.pdf", "text": "caption" }
  Future<UazapiResponse<SendMessageResult>> enviarDocumento({
    required String instanceToken,
    required String telefone,
    required String documentUrl,
    String? filename,
    String? caption,
  }) async {
    try {
      final numero = _formatarNumeroWhatsApp(telefone);
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/send/media'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({
          'number': numero,
          'type': 'document',
          'file': documentUrl,
          if (filename != null) 'docName': filename,
          'text': caption ?? '',
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(SendMessageResult.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao enviar documento');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Enviar áudio
  /// POST /send/media
  /// Body: { "number": "5511999999999", "type": "audio", "file": "url" }
  Future<UazapiResponse<SendMessageResult>> enviarAudio({
    required String instanceToken,
    required String telefone,
    required String audioUrl,
  }) async {
    try {
      final numero = _formatarNumeroWhatsApp(telefone);
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/send/media'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({
          'number': numero,
          'type': 'audio',
          'file': audioUrl,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(SendMessageResult.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao enviar áudio');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Enviar áudio como mensagem de voz (PTT)
  /// POST /send/media
  /// Body: { "number": "5511999999999", "type": "ptt", "file": "url" }
  Future<UazapiResponse<SendMessageResult>> enviarAudioVoz({
    required String instanceToken,
    required String telefone,
    required String audioUrl,
  }) async {
    try {
      final numero = _formatarNumeroWhatsApp(telefone);
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/send/media'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({
          'number': numero,
          'type': 'ptt',
          'file': audioUrl,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(SendMessageResult.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao enviar áudio de voz');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Enviar sticker/figurinha
  /// POST /send/media
  /// Body: { "number": "5511999999999", "type": "sticker", "file": "url" }
  Future<UazapiResponse<SendMessageResult>> enviarSticker({
    required String instanceToken,
    required String telefone,
    required String stickerUrl,
  }) async {
    try {
      final numero = _formatarNumeroWhatsApp(telefone);
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/send/media'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({
          'number': numero,
          'type': 'sticker',
          'file': stickerUrl,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(SendMessageResult.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao enviar sticker');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  // ============================================
  // DOWNLOAD MEDIA
  // ============================================

  /// Baixar áudio
  /// POST /media/download-audio
  Future<UazapiResponse<String>> baixarAudio({
    required String instanceToken,
    required String messageId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/media/download-audio'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({'messageId': messageId}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return UazapiResponse.success(data['url'] as String? ?? '');
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao baixar áudio');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Baixar imagem
  /// POST /media/download-image
  Future<UazapiResponse<String>> baixarImagem({
    required String instanceToken,
    required String messageId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/media/download-image'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({'messageId': messageId}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return UazapiResponse.success(data['url'] as String? ?? '');
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao baixar imagem');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Baixar documento
  /// POST /media/download-doc
  Future<UazapiResponse<String>> baixarDocumento({
    required String instanceToken,
    required String messageId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/media/download-doc'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({'messageId': messageId}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return UazapiResponse.success(data['url'] as String? ?? '');
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao baixar documento');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  // ============================================
  // MASS MESSAGES
  // ============================================

  /// Enviar mensagem em massa (texto)
  /// POST /message/send-mass-text
  Future<UazapiResponse<MassMessageResult>> enviarMensagemMassa({
    required String instanceToken,
    required List<String> telefones,
    required String mensagem,
    int? delay, // delay entre mensagens em segundos
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/message/send-mass-text'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({
          'telefones': telefones,
          'mensagem': mensagem,
          if (delay != null) 'delay': delay,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(MassMessageResult.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao enviar mensagem em massa');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  // ============================================
  // CAMPAIGNS (SENDER)
  // ============================================

  /// Criar campanha simples (sender)
  /// POST /sender/simple
  Future<UazapiResponse<Map<String, dynamic>>> criarCampanhaSimples({
    required String instanceToken,
    required List<String> telefones,
    required String tipo,
    required String folder,
    required int delayMin,
    required int delayMax,
    required int scheduledFor,
    String? text,
    String? file,
    String? info,
    int? delay,
  }) async {
    try {
      final numbers = telefones.map(_formatarNumeroWhatsApp).toList();
      final body = <String, dynamic>{
        'numbers': numbers,
        'type': tipo,
        'folder': folder,
        'delayMin': delayMin,
        'delayMax': delayMax,
        'scheduled_for': scheduledFor,
      };
      if (info != null) body['info'] = info;
      if (delay != null) body['delay'] = delay;
      if (text != null) body['text'] = text;
      if (file != null) body['file'] = file;

      final response = await _client.post(
        Uri.parse('$_baseUrl/sender/simple'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(Map<String, dynamic>.from(data));
      }
      return UazapiResponse.error(
        data['message']?.toString() ?? 'Erro ao criar campanha',
      );
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Listar campanhas (folders)
  /// GET /sender/listfolders
  Future<UazapiResponse<List<UazapiFolderCampaign>>> listarCampanhas({
    required String instanceToken,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/sender/listfolders'),
        headers: _headers(instanceToken: instanceToken),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final list = (data as List<dynamic>)
            .map((e) => UazapiFolderCampaign.fromJson(e))
            .toList();
        return UazapiResponse.success(list);
      }
      return UazapiResponse.error(
        data['message']?.toString() ?? 'Erro ao listar campanhas',
      );
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  /// Buscar campanha específica pelo folder (id)
  /// Faz GET /sender/listfolders e filtra pelo id
  Future<UazapiResponse<UazapiFolderCampaign?>> buscarCampanhaPorFolder({
    required String instanceToken,
    required String folderId,
  }) async {
    final result = await listarCampanhas(instanceToken: instanceToken);
    if (!result.isSuccess) {
      return UazapiResponse.error(result.error ?? 'Erro ao buscar campanhas');
    }

    final campanhas = result.data ?? [];
    final campanha = campanhas.where((c) => c.id == folderId).firstOrNull;
    return UazapiResponse.success(campanha);
  }

  /// Enviar arquivos em massa
  /// POST /message/send-mass-files
  Future<UazapiResponse<MassMessageResult>> enviarArquivosMassa({
    required String instanceToken,
    required List<String> telefones,
    required String fileUrl,
    String? caption,
    int? delay,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/message/send-mass-files'),
        headers: _headers(instanceToken: instanceToken),
        body: jsonEncode({
          'telefones': telefones,
          'url': fileUrl,
          if (caption != null) 'caption': caption,
          if (delay != null) 'delay': delay,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UazapiResponse.success(MassMessageResult.fromJson(data));
      }
      
      return UazapiResponse.error(data['message'] ?? 'Erro ao enviar arquivos em massa');
    } catch (e) {
      return UazapiResponse.error('Erro de conexão: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}

// ============================================
// RESPONSE WRAPPER
// ============================================

class UazapiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  UazapiResponse._({this.data, this.error, required this.isSuccess});

  factory UazapiResponse.success(T data) {
    return UazapiResponse._(data: data, isSuccess: true);
  }

  factory UazapiResponse.error(String message) {
    return UazapiResponse._(error: message, isSuccess: false);
  }
}

// ============================================
// MODELS
// ============================================

class InstanceStatus {
  final bool connected;
  final String? phone;
  final String? name;
  final String? status;

  InstanceStatus({
    required this.connected,
    this.phone,
    this.name,
    this.status,
  });

  factory InstanceStatus.fromJson(Map<String, dynamic> json) {
    final instance = json['instance'] as Map<String, dynamic>?;
    return InstanceStatus(
      connected: instance?['connected'] as bool? ?? false,
      phone: instance?['phone'] as String?,
      name: instance?['name'] as String?,
      status: instance?['status'] as String?,
    );
  }
}

class UazapiChat {
  final String id;
  final String? name;
  final String? phone;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int? unreadCount;
  final String? profilePicture;

  UazapiChat({
    required this.id,
    this.name,
    this.phone,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount,
    this.profilePicture,
  });

  factory UazapiChat.fromJson(Map<String, dynamic> json) {
    return UazapiChat(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.tryParse(json['lastMessageTime'] as String)
          : null,
      unreadCount: json['unreadCount'] as int?,
      profilePicture: json['profilePicture'] as String?,
    );
  }
}

class UazapiMessage {
  final String id;
  final String? body;
  final String? type;
  final bool fromMe;
  final String? phone;
  final DateTime? timestamp;
  final String? mediaUrl;

  UazapiMessage({
    required this.id,
    this.body,
    this.type,
    required this.fromMe,
    this.phone,
    this.timestamp,
    this.mediaUrl,
  });

  factory UazapiMessage.fromJson(Map<String, dynamic> json) {
    return UazapiMessage(
      id: json['id'] as String? ?? '',
      body: json['body'] as String?,
      type: json['type'] as String?,
      fromMe: json['fromMe'] as bool? ?? false,
      phone: json['phone'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['timestamp'] as num).toInt() * 1000)
          : null,
      mediaUrl: json['mediaUrl'] as String?,
    );
  }
}

class UazapiFolderCampaign {
  final String id;
  final String? info;
  final String? status;
  final int? scheduledFor;
  final int? delayMax;
  final int? delayMin;
  final int? logDelivered;
  final int? logFailed;
  final int? logPlayed;
  final int? logRead;
  final int? logSuccess;
  final int? logTotal;
  final String? owner;
  final DateTime? created;
  final DateTime? updated;

  UazapiFolderCampaign({
    required this.id,
    this.info,
    this.status,
    this.scheduledFor,
    this.delayMax,
    this.delayMin,
    this.logDelivered,
    this.logFailed,
    this.logPlayed,
    this.logRead,
    this.logSuccess,
    this.logTotal,
    this.owner,
    this.created,
    this.updated,
  });

  factory UazapiFolderCampaign.fromJson(Map<String, dynamic> json) {
    return UazapiFolderCampaign(
      id: json['id'] as String? ?? '',
      info: json['info'] as String?,
      status: json['status'] as String?,
      scheduledFor: json['scheduled_for'] as int?,
      delayMax: json['delayMax'] as int?,
      delayMin: json['delayMin'] as int?,
      logDelivered: json['log_delivered'] as int?,
      logFailed: json['log_failed'] as int?,
      logPlayed: json['log_played'] as int?,
      logRead: json['log_read'] as int?,
      logSuccess: json['log_sucess'] as int?,
      logTotal: json['log_total'] as int?,
      owner: json['owner'] as String?,
      created: json['created'] != null
          ? DateTime.tryParse(json['created'] as String)
          : null,
      updated: json['updated'] != null
          ? DateTime.tryParse(json['updated'] as String)
          : null,
    );
  }
}

class UazapiContact {
  final String? id;
  final String? name;
  final String? phone;
  final String? profilePicture;
  final String? status;

  UazapiContact({
    this.id,
    this.name,
    this.phone,
    this.profilePicture,
    this.status,
  });

  factory UazapiContact.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'] as Map<String, dynamic>? ?? json;
    return UazapiContact(
      id: contact['id'] as String?,
      name: contact['name'] as String?,
      phone: contact['phone'] as String?,
      profilePicture: contact['profilePicture'] as String?,
      status: contact['status'] as String?,
    );
  }
}

class SendMessageResult {
  final bool success;
  final String? messageId;
  final String? error;

  SendMessageResult({
    required this.success,
    this.messageId,
    this.error,
  });

  factory SendMessageResult.fromJson(Map<String, dynamic> json) {
    return SendMessageResult(
      success: json['success'] as bool? ?? true,
      messageId: json['messageId'] as String? ?? json['id'] as String?,
      error: json['error'] as String?,
    );
  }
}

class MassMessageResult {
  final bool success;
  final int? sent;
  final int? failed;
  final List<String>? errors;

  MassMessageResult({
    required this.success,
    this.sent,
    this.failed,
    this.errors,
  });

  factory MassMessageResult.fromJson(Map<String, dynamic> json) {
    return MassMessageResult(
      success: json['success'] as bool? ?? true,
      sent: json['sent'] as int?,
      failed: json['failed'] as int?,
      errors: (json['errors'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }
}
