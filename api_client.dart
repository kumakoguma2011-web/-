import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception { const ApiException(this.status,this.message); final int status; final String message; @override String toString()=>message; }
class ApiClient {
  ApiClient(this.baseUrl,{http.Client? client,this.onUnauthorized}):_client=client??http.Client();
  final String baseUrl; final http.Client _client; String? accessToken; Future<void> Function()? onUnauthorized;
  Map<String,String> get _headers=>{'Accept':'application/json','Content-Type':'application/json',if(accessToken!=null)'Authorization':'Bearer $accessToken'};

  Uri _uri(String path) {
    final base = Uri.parse(baseUrl);
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    final normalizedBase = base.replace(path: basePath);
    final relativePath = path.replaceFirst(RegExp(r'^/+'), '');
    return normalizedBase.resolve(relativePath);
  }

  Future<Map<String,dynamic>> post(String path,Map<String,dynamic> body)async=>_decode(await _client.post(_uri(path),headers:_headers,body:jsonEncode(body)).timeout(const Duration(seconds:35)));
  Future<List<Map<String,dynamic>>> getList(String path)async{final r=await _client.get(_uri(path),headers:_headers).timeout(const Duration(seconds:35));if(r.statusCode<200||r.statusCode>=300)await _throw(r);final x=jsonDecode(r.body) as List;return x.map((e)=>Map<String,dynamic>.from(e as Map)).toList();}
  Future<Map<String,dynamic>> get(String path)async=>_decode(await _client.get(_uri(path),headers:_headers).timeout(const Duration(seconds:35)));
  Future<Map<String,dynamic>> put(String path,Map<String,dynamic> body)async=>_decode(await _client.put(_uri(path),headers:_headers,body:jsonEncode(body)).timeout(const Duration(seconds:35)));
  Future<void> delete(String path)async{final r=await _client.delete(_uri(path),headers:_headers).timeout(const Duration(seconds:35));if(r.statusCode<200||r.statusCode>=300)await _throw(r);}
  Future<Map<String,dynamic>> _decode(http.Response r)async{if(r.statusCode<200||r.statusCode>=300)await _throw(r);return r.body.isEmpty?{}:jsonDecode(r.body) as Map<String,dynamic>;}
  Future<Never> _throw(http.Response r)async{if(r.statusCode==401&&onUnauthorized!=null)await onUnauthorized!();throw ApiException(r.statusCode,_message(r.body));}
  String _message(String body){try{final x=jsonDecode(body);return x['message']?.toString()??'通信に失敗しました';}catch(_){return '通信に失敗しました';}}
}
