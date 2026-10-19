
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../core/theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, required this.onSignedIn});
  final ApiClient api;
  final Future<void> Function(String,String) onSignedIn;
  @override State<AuthScreen> createState()=>_AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen>{
  final email=TextEditingController(), pass=TextEditingController();
  bool register=false,busy=false;
  Future<void> submit() async {
    setState(()=>busy=true);
    try {
      final x=await widget.api.post(register?'/auth/register':'/auth/login',{'email':email.text.trim(),'password':pass.text});
      await widget.onSignedIn(x['access_token'].toString(), email.text.trim().toLowerCase());
      if(mounted) pass.clear();
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));
    } finally { if(mounted)setState(()=>busy=false); }
  }
  @override void dispose(){email.dispose();pass.dispose();super.dispose();}
  @override Widget build(BuildContext c)=>Scaffold(
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: MichishirubeTheme.accent, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.route_outlined, color: Colors.white, size: 39),
          ),
          const SizedBox(height: 18),
          const Text('ミチシルベ', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: MichishirubeTheme.ink)),
          const SizedBox(height: 6),
          const Text('答えを急がず、一緒に整理するキャリア相談室', textAlign: TextAlign.center, style: TextStyle(color: MichishirubeTheme.muted, height: 1.5)),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(register?'アカウントを作成':'おかえりなさい', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                TextField(controller:email, keyboardType:TextInputType.emailAddress, decoration:const InputDecoration(labelText:'メールアドレス')),
                const SizedBox(height:12),
                TextField(controller:pass, obscureText:true, decoration:const InputDecoration(labelText:'パスワード（12文字以上）')),
                const SizedBox(height:20),
                FilledButton(onPressed:busy?null:submit, child:Text(busy?'処理中…':register?'アカウントを作成':'ログイン')),
                TextButton(onPressed:busy?null:()=>setState(()=>register=!register), child:Text(register?'ログインへ戻る':'新規アカウントを作成')),
                const SizedBox(height:6),
                const Text('Gemini APIキーはこのアプリに保存しません。AI通信はRustバックエンド経由です。', textAlign:TextAlign.center, style:TextStyle(fontSize:11,color:MichishirubeTheme.muted,height:1.5)),
              ]),
            ),
          ),
        ]),
      ),
    )),
  );
}
