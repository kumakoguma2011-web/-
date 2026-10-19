import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/career.dart';
import '../../services/api_client.dart';
import '../../services/local_vault.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key, required this.api, required this.vault, required this.onLogout, required this.onActivity});
  final ApiClient api; final LocalVault vault; final Future<void> Function() onLogout; final VoidCallback onActivity;
  @override State<PrivacyScreen> createState()=>_PrivacyScreenState();
}
class _PrivacyScreenState extends State<PrivacyScreen>{
  List<ProfileSuggestionRecord> suggestionHistory=[];
  final original=TextEditingController(), label=TextEditingController(); List<AnonRule> rules=[]; bool zero=false; String tone='優しく励ます'; int step=1;
  @override void initState(){super.initState();_load();}
  Future<void>_load()async{final settings=await widget.vault.readSettings();zero=settings['zero_context']==true;tone=settings['tone']?.toString()??tone;step=int.tryParse(settings['step']?.toString()??'1')??1;try{final x=await widget.api.getList('/anon-rules');rules=x.map(AnonRule.fromJson).toList();await widget.vault.saveRules(rules);}catch(_){rules=await widget.vault.readRules();}
    suggestionHistory=await widget.vault.readProfileSuggestions();if(mounted)setState((){});}
  Future<void>add()async{final o=original.text.trim(),l=label.text.trim();if(o.isEmpty||l.isEmpty||o==l)return;try{final x=await widget.api.post('/anon-rules',{'original':o,'label':l});if(!mounted)return;final r=AnonRule.fromJson(x);setState(()=>rules.add(r));await widget.vault.saveRules(rules);original.clear();label.clear();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
  Future<void>deleteRule(AnonRule r)async{try{await widget.api.delete('/anon-rules/${r.id}');if(!mounted)return;setState(()=>rules.removeWhere((x)=>x.id==r.id));await widget.vault.saveRules(rules);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
  Future<void>emergencyWipe()async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('緊急データ破棄'),content:const Text('この端末に保存されているミチシルベの保護データ、認証情報、表示中のセッションを即時に削除してログアウトします。サーバー上のアカウントは削除しません。'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('キャンセル')),FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.red),onPressed:()=>Navigator.pop(c,true),child:const Text('端末データを破棄'))]));if(ok==true)await widget.onLogout();}
  Future<void>deleteAll()async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('アカウントを削除しますか？'),content:const Text('プロフィール、仮名化ルール、会話履歴、アカウント情報をサーバーから削除します。元に戻せません。'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('キャンセル')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('削除する'))]));if(ok!=true)return;try{await widget.api.delete('/account/data');await widget.onLogout();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
  Future<void>exportData()async{try{final data=await widget.api.get('/account/export');final text=const JsonEncoder.withIndent('  ').convert(data);await SharePlus.instance.share(ShareParams(text:text,subject:'ミチシルベ データエクスポート'));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
  Future<void>openExternalDeletion()async{final base=Uri.parse(widget.api.baseUrl);final uri=base.replace(path:'${base.path.endsWith('/')?base.path.substring(0,base.path.length-1):base.path}/account-deletion');if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('削除ページを開けませんでした。')));}
  @override void dispose(){original.dispose();label.dispose();super.dispose();}
  Widget _securityCard(String title,String body,IconData icon)=>Card(child:ExpansionTile(leading:Icon(icon,color:Colors.green.shade700),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,16),child:Align(alignment:Alignment.centerLeft,child:Text(body,style:const TextStyle(height:1.5))))]));
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[
    const Text('プライバシー・安全設定',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
    const SizedBox(height:6),const Text('ミチシルベは「何をAIに送るかを自分で確認・制御できること」を重視しています。'),
    const SizedBox(height:12),
    SwitchListTile(title:const Text('ZERO-CONTEXT'),subtitle:const Text('プロフィールをAIへ送信しない'),value:zero,onChanged:(v)async{setState(()=>zero=v);await widget.vault.saveSettings(v,tone,step);}),
    const Divider(),
    const Text('仮名化ルール',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),
    TextField(controller:original,onChanged:(_)=>widget.onActivity(),decoration:const InputDecoration(labelText:'置換前（会社名・氏名など）')),const SizedBox(height:8),TextField(controller:label,onChanged:(_)=>widget.onActivity(),decoration:const InputDecoration(labelText:'置換後ラベル')),const SizedBox(height:8),
    FilledButton(onPressed:add,child:const Text('仮名化ルールを追加')),
    ...rules.map((r)=>ListTile(title:Text(r.original),subtitle:Text('→ ${r.label}'),trailing:IconButton(onPressed:()=>deleteRule(r),icon:const Icon(Icons.delete_outline)))),
    const SizedBox(height:16),
    _securityCard('① 送信データ透明性', '相談画面の「送信前に確認」から、今回のリクエストでAIへ渡す文章をRustサーバーが仮名化した状態で確認できます。ZERO-CONTEXTではプロフィールを含めません。', Icons.visibility_outlined),
    _securityCard('② 仮名化', '電話番号・メール・郵便番号・日付パターンと、登録した会社名・氏名などのルールを送信前に置換します。完全な匿名化を保証する機能ではないため、送信前確認を推奨します。', Icons.person_off_outlined),
    _securityCard('③ 端末保護', 'アクセストークン、プロフィール、仮名化ルール、設定は端末の安全なストレージにユーザー単位で保存します。', Icons.lock_outline),
    _securityCard('④ サーバー側保護', 'Gemini APIキーはアプリに保存せず、Rustバックエンドだけが保持します。認証・ユーザー所有権・入力上限・レート制限をサーバー側でも検証します。', Icons.dns_outlined),
    _securityCard('⑤ データ削除', '「緊急データ破棄」は端末内のデータを消してログアウトします。「アカウントと全データを削除」はサーバー側のアカウント関連データも削除します。', Icons.delete_forever_outlined),

    const SizedBox(height:12),
    Card(child:ExpansionTile(leading:Icon(Icons.history,color:Colors.green.shade700),title:const Text('AIプロフィール提案の確認履歴',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('AIが提案し、あなたが採用・見送りした内容'),children:[
      if(suggestionHistory.isEmpty) const Padding(padding:EdgeInsets.all(16),child:Align(alignment:Alignment.centerLeft,child:Text('まだ履歴はありません。'))),
      for(final h in suggestionHistory.take(10)) ListTile(leading:Icon(h.accepted?Icons.check_circle_outline:Icons.remove_circle_outline,color:h.accepted?Colors.green:Colors.grey),title:Text(h.text),subtitle:Text(h.accepted?'採用':'見送り'),dense:true),
    ])),
    const SizedBox(height:12),
    OutlinedButton.icon(onPressed:exportData,icon:const Icon(Icons.download_outlined),label:const Text('データをエクスポート')),
    const SizedBox(height:8),
    FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:Colors.red.shade700,foregroundColor:Colors.white),onPressed:emergencyWipe,icon:const Icon(Icons.warning_amber_rounded),label:const Text('緊急データ破棄（端末）')),
    const SizedBox(height:8),
    FilledButton.tonalIcon(onPressed:deleteAll,icon:const Icon(Icons.delete_forever),label:const Text('アカウントと全データを削除')),
    const SizedBox(height:8),
    OutlinedButton.icon(onPressed:openExternalDeletion,icon:const Icon(Icons.open_in_new),label:const Text('Webからアカウント削除を開始')),
  ]);
}
