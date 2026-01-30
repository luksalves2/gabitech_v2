import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service para buscar endereço via CEP usando ViaCEP API
class ViaCepService {
  static const String _baseUrl = 'https://viacep.com.br/ws';

  /// Busca endereço pelo CEP
  /// Retorna null se o CEP for inválido ou não encontrado
  static Future<ViaCepResponse?> buscarCep(String cep) async {
    try {
      // Remove caracteres não numéricos
      final cleanCep = cep.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (cleanCep.length != 8) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/$cleanCep/json/'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // ViaCEP retorna "erro": true quando não encontra
        if (data['erro'] == true) {
          return null;
        }
        
        return ViaCepResponse.fromJson(data);
      }
      
      return null;
    } catch (e) {
      print('Erro ao buscar CEP: $e');
      return null;
    }
  }
}

/// Resposta da API ViaCEP
class ViaCepResponse {
  final String cep;
  final String logradouro;
  final String complemento;
  final String bairro;
  final String localidade; // cidade
  final String uf; // estado
  final String? ibge;
  final String? gia;
  final String? ddd;
  final String? siafi;

  ViaCepResponse({
    required this.cep,
    required this.logradouro,
    required this.complemento,
    required this.bairro,
    required this.localidade,
    required this.uf,
    this.ibge,
    this.gia,
    this.ddd,
    this.siafi,
  });

  factory ViaCepResponse.fromJson(Map<String, dynamic> json) {
    return ViaCepResponse(
      cep: json['cep'] ?? '',
      logradouro: json['logradouro'] ?? '',
      complemento: json['complemento'] ?? '',
      bairro: json['bairro'] ?? '',
      localidade: json['localidade'] ?? '',
      uf: json['uf'] ?? '',
      ibge: json['ibge'],
      gia: json['gia'],
      ddd: json['ddd'],
      siafi: json['siafi'],
    );
  }
}
