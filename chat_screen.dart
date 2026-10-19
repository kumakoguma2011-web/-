import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import '../../models/career.dart';
import '../../services/api_client.dart';
import '../../services/local_vault.dart';
import '../../core/theme.dart';

class ChatScreen extends StatefulWidget{const ChatScreen({super.key,required this.api,required this.vault,required this.onActivity,this.newChatSignal});final ApiClient api;final LocalVault vault;final VoidCallback onActivity;final ValueNotifier<int>? newChatSignal;@override State<ChatScreen>createState()=>_ChatScreenState();}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.onStart, required this.onNewChat, required this.onPrompt});
  final VoidCallback onStart;
  final Future<void> Function() onNewChat;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const prompts = [
      ('進路について迷っている', Icons.explore_outlined),
      ('自分に向いている仕事を知りたい', Icons.work_outline),
      ('将来やりたいことが分からない', Icons.lightbulb_outline),
      ('学校生活や人間関係を相談したい', Icons.people_outline),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              const SizedBox(height: 18),
              Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  color: MichishirubeTheme.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 7))],
                ),
                child: const Icon(Icons.route_outlined, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 18),
              Text('AIに相談してみませんか？', textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 8),
              Text('まだ答えが決まっていなくても大丈夫。\n今の気持ちを、そのまま話してください。', textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: MichishirubeTheme.muted, height: 1.65)),
              const SizedBox(height: 26),
              Align(alignment: Alignment.centerLeft, child: Text('こんな相談から始められます',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 9, runSpacing: 9,
                children: prompts.map((p) => ActionChip(
                  avatar: Icon(p.$2, size: 18, color: MichishirubeTheme.accent),
                  label: Text(p.$1),
                  onPressed: () => onPrompt(p.$1),
                  backgroundColor: MichishirubeTheme.paper,
                  side: const BorderSide(color: Color(0xFFDCCFC1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                )).toList(),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: MichishirubeTheme.paper,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE0D6CA)),
                  boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 14, offset: Offset(0, 5))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 34, height: 34,
                      decoration: BoxDecoration(color: const Color(0xFFE9DED2), borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.auto_awesome_outlined, color: MichishirubeTheme.accent, size: 19)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('ミチシルベ AI相談', style: TextStyle(fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 12),
                  const Text('「何から話せばいいか分からない」でもOKです。AIが質問しながら、一緒に考えを整理します。', style: TextStyle(height: 1.55)),
                  const SizedBox(height: 15),
                  Row(children: [
                    Expanded(child: FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.chat_bubble_outline), label: const Text('相談を始める'))),
                    const SizedBox(width: 9),
                    IconButton(onPressed: () => onNewChat(), tooltip: '新しい相談', icon: const Icon(Icons.add_comment_outlined)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                Icon(Icons.lock_outline, size: 15, color: MichishirubeTheme.muted),
                SizedBox(width: 5), Text('相談内容の送信設定を確認できます', style: TextStyle(fontSize: 12, color: MichishirubeTheme.muted)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(0xFFE9DED2),
        child: Icon(icon, color: MichishirubeTheme.accent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(body)),
    ),
  );
}

class _ChatScreenState extends State<ChatScreen>{final input=TextEditingController();final messages=<ChatMessage>[];final speech=SpeechToText();bool busy=false,zero=false,listening=false;int step=1;String tone='優しく励ます';String? conversationId;String? attachedName;String? attachedText;
 @override void initState(){super.initState();widget.newChatSignal?.addListener(_onNewChatSignal);_restore();}
 void _onNewChatSignal(){if(mounted && !busy)_newChat();}
 Future<void>_restore()async{final x=await widget.vault.readSettings();if(!mounted)return;zero=x['zero_context']==true;tone=x['tone']?.toString()??tone;step=int.tryParse(x['step']?.toString()??'1')??1;try{final latest=await widget.api.get('/conversations/latest');if(!mounted)return;final id=latest['conversation_id']?.toString();if(id!=null){conversationId=id;final rows=await widget.api.getList('/conversations/$id/messages');if(!mounted)return;messages.addAll(rows.map(ChatMessage.fromJson));}}catch(_){ }if(mounted)setState((){});}
 Future<void>_saveSettings()async=>widget.vault.saveSettings(zero,tone,step);
 Future<void>_send()async{
  final text=input.text.trim();
  if((text.isEmpty&&attachedText==null)||busy)return;
  widget.onActivity();
  input.clear();
  final attachmentText=attachedText;
  final attachmentName=attachedName;
  final displayText = attachmentName == null
      ? text
      : (text.isEmpty ? '【添付ファイル】$attachmentName' : '$text\n【添付ファイル】$attachmentName');
  setState((){
    messages.add(ChatMessage(role:'user',content:displayText,step:step));
    busy=true;
  });
  attachedName=null;
  attachedText=null;
  final clientMessageId=const Uuid().v4();
  try{
    final x=await widget.api.post('/chat',{
      'conversation_id':conversationId,
      'client_message_id':clientMessageId,
      'message':text,
      'attachment_text':attachmentText,
      'attachment_name':attachmentName,
      'zero_context':zero,
      'step':step,
      'tone':tone,
    });
    if(!mounted)return;
    conversationId=x['conversation_id']?.toString();
    step=int.tryParse(x['step'].toString())??step;
    final answer=x['answer']?.toString()??'';
    setState(()=>messages.add(ChatMessage(role:'assistant',content:answer,step:step)));
    final updates=(x['profile_updates'] as List? ?? const [])
        .map((e)=>e.toString())
        .where((e)=>e.trim().isNotEmpty)
        .toList();
    if(updates.isNotEmpty && mounted)_showProfileUpdateSuggestion(updates);
    await _saveSettings();
  }catch(e){
    if(mounted)setState(()=>messages.add(ChatMessage(role:'assistant',content:'AIへの接続に失敗しました。${e.toString()}',step:step)));
  }finally{
    if(mounted)setState(()=>busy=false);
  }
 }
 Future<void>_recordSuggestion(List<String>updates,bool accepted)async{
  for(final u in updates.take(5)){
    try{await widget.vault.saveProfileSuggestion(ProfileSuggestionRecord(text:u.trim(),accepted:accepted,createdAt:DateTime.now().toIso8601String()));}catch(_){/* Suggestion history is best-effort and must not hide the primary action result. */}
  }
}
 Future<bool>_applyProfileUpdates(List<String>updates)async{
  try{
    final x=await widget.api.get('/profile');
    final p=ProfileData.fromJson(x);
    final next=[p.freeText,...updates.take(5).map((u){
      final value=u.trim();
      return '・[AI自動抽出] ${value.substring(0,value.length>500?500:value.length)}';
    })].where((v)=>v.trim().isNotEmpty).join('\n');
    await widget.api.put('/profile',{...p.toJson(),'free_text':next});
    try{
      await widget.vault.saveProfile(ProfileData(freeText:next,status:p.status,gender:p.gender,location:p.location,personality:p.personality,relationships:p.relationships,hobbies:p.hobbies,priority:p.priority));
    }catch(_){ /* The server copy was saved successfully. */ }
    return true;
  }catch(_){
    return false;
  }
 }
void _showProfileUpdateSuggestion(List<String>updates){
  final text=updates.take(5).map((e){final value=e.trim();return '• ${value.substring(0,value.length>300?300:value.length)}';}).join('\n');
  showDialog(context:context,builder:(c)=>AlertDialog(
    title:const Text('AIからのプロフィール更新案'),
    content:Text(text),
    actions:[
      TextButton(onPressed:()async{
        Navigator.pop(c);
        await _recordSuggestion(updates,false);
      },child:const Text('今回は追加しない')),
      FilledButton(onPressed:()async{
        Navigator.pop(c);
        final saved=await _applyProfileUpdates(updates);
        if(!mounted)return;
        if(saved){
          await _recordSuggestion(updates,true);
          if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('プロフィールに追加しました')));
        }else{
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('プロフィールを保存できませんでした。通信状態を確認して、もう一度お試しください。')));
        }
      },child:const Text('プロフィールに追加')),
    ],
  ));
}
 Future<void>_previewPrompt()async{
 widget.onActivity();
 if(busy)return;
 final text=input.text.trim();
 if(text.isEmpty&&attachedText==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('送信内容を入力してください。')));return;}
 try{
   final x=await widget.api.post('/chat/preview',{'conversation_id':conversationId,'client_message_id':const Uuid().v4(),'message':text,'attachment_text':attachedText,'attachment_name':attachedName,'zero_context':zero,'step':step,'tone':tone});
   final prompt=x['prompt']?.toString()??''; final included=x['profile_included']==true; final attached=x['attachment_included']==true;
   if(!mounted)return;
   showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('送信データを確認'),content:SizedBox(width:620,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(included?'プロフィール：送信します':'プロフィール：送信しません',style:TextStyle(fontWeight:FontWeight.w800,color:included?Colors.orange.shade800:Colors.green.shade800)),const SizedBox(height:6),Text(attached?'添付：送信します':'添付：なし'),const SizedBox(height:12),const Text('Rustサーバーで仮名化後、Geminiへ送る予定の内容',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),SelectableText(prompt,style:const TextStyle(fontSize:12,height:1.45,fontFamily:'monospace'))])),),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('閉じる'))]));
 }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('送信データの取得に失敗しました。${e.toString()}')));}
}
Future<void>_newChat()async{if(busy)return;widget.onActivity();try{final x=await widget.api.post('/conversations',{});final id=x['conversation_id']?.toString();if(id==null||id.isEmpty)throw Exception('新規相談IDを取得できませんでした');if(!mounted)return;setState((){messages.clear();conversationId=id;step=1;attachedName=null;attachedText=null;});await _saveSettings();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('新しい相談を開始しました')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('新規相談を開始できませんでした。${e.toString()}')));}}
 Future<void>_deleteConversation()async{
  if(busy||conversationId==null)return;
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('この相談を削除しますか？'),content:const Text('この会話の履歴をサーバーから削除します。アカウントやプロフィールは削除されません。'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('キャンセル')),FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.red),onPressed:()=>Navigator.pop(c,true),child:const Text('相談を削除'))]));
  if(!mounted||ok!=true)return;
  widget.onActivity();
  try{await widget.api.delete('/conversations/$conversationId');if(!mounted)return;setState((){messages.clear();conversationId=null;step=1;attachedName=null;attachedText=null;});await _saveSettings();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('この相談を削除しました')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('相談の削除に失敗しました。$e')));}
 }
 Future<void>_pickFile()async{widget.onActivity();final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const ['txt','md','csv','json'],withData:true);if(!mounted||r==null||r.files.isEmpty)return;final f=r.files.first;if(f.size>256*1024){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('添付ファイルは256KB以下にしてください。')));return;}final bytes=f.bytes;if(bytes==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ファイルを読み込めませんでした。')));return;}try{final decoded=utf8.decode(bytes);widget.onActivity();if(!mounted)return;setState((){attachedName=f.name;attachedText=decoded;});}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('UTF-8のテキストファイルを選択してください。')));}}
 Future<void>_voice()async{
  widget.onActivity();
  if(!listening){
    try{
      final ok=await speech.initialize();
      if(!mounted)return;
      if(!ok){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('音声入力を利用できません。マイク権限をご確認ください。')));return;}
      setState(()=>listening=true);
      await speech.listen(localeId:'ja-JP',onResult:(SpeechRecognitionResult r){
        if(!mounted)return;
        input.text=r.recognizedWords;
        input.selection=TextSelection.collapsed(offset:input.text.length);
        if(r.finalResult)setState(()=>listening=false);
      });
    }catch(_){
      if(mounted){setState(()=>listening=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('音声入力を開始できませんでした。')));}
    }
  }else{
    try{
      await speech.stop();
      if(mounted)setState(()=>listening=false);
    }catch(_){
      if(mounted){setState(()=>listening=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('音声入力を停止できませんでした。')));}
    }
  }
 }
 @override void dispose(){widget.newChatSignal?.removeListener(_onNewChatSignal);speech.stop();input.dispose();super.dispose();}
 Widget _stepChips()=>SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[for(int i=1;i<=5;i++)Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text('ステップ$i'),selected:step==i,onSelected:(v)async{if(v){widget.onActivity();setState(()=>step=i);await _saveSettings();}}))]));
 
@override Widget build(BuildContext c) {
  final theme = Theme.of(c);
  return Column(children: [
    Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 10),
      decoration: const BoxDecoration(
        color: MichishirubeTheme.parchment,
        border: Border(bottom: BorderSide(color: Color(0xFFE0D7CC))),
      ),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFE9DED2), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.route_outlined, color: MichishirubeTheme.accent, size: 19)),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AIへの相談', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text('あなたの考えを一緒に整理します', style: TextStyle(fontSize: 11, color: MichishirubeTheme.muted)),
        ])),
        IconButton(tooltip:'送信データを確認', onPressed:busy?null:_previewPrompt, icon:const Icon(Icons.visibility_outlined)),
        IconButton(tooltip:'新しい相談', onPressed:busy?null:_newChat, icon:const Icon(Icons.add_comment_outlined)),
        IconButton(tooltip:'この相談を削除', onPressed:busy||conversationId==null?null:_deleteConversation, icon:const Icon(Icons.delete_outline)),
      ]),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(children: [
        Icon(Icons.lock_outline, size: 16, color: zero ? MichishirubeTheme.sage : MichishirubeTheme.muted),
        const SizedBox(width: 7),
        Expanded(child: Text(zero ? 'ZERO-CONTEXT：プロフィールを使わず相談中' : 'プロフィールを参考に相談中',
          style: TextStyle(fontSize: 12, color: zero ? MichishirubeTheme.sage : MichishirubeTheme.muted))),
        Switch(value:zero, onChanged:(v)async{widget.onActivity();setState(()=>zero=v);await _saveSettings();}),
      ]),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DropdownButtonFormField<String>(
        value:tone,
        items:const ['優しく励ます','はっきり伝える','静かに聞く'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
        onChanged:(v)async{if(v!=null){widget.onActivity();setState(()=>tone=v);await _saveSettings();}},
        decoration:const InputDecoration(labelText:'AIのトーン', isDense:true),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(alignment:Alignment.centerLeft,child:_stepChips()),
    ),
    Expanded(
      child: messages.isEmpty
        ? _WelcomeView(
            onStart:(){FocusScope.of(c).requestFocus();widget.onActivity();},
            onNewChat:_newChat,
            onPrompt:(text){input.text=text;input.selection=TextSelection.collapsed(offset:text.length);FocusScope.of(c).requestFocus();widget.onActivity();setState((){});},
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount:messages.length,
            itemBuilder:(c,i){
              final m=messages[i]; final isUser=m.role=='user';
              return Align(
                alignment:isUser?Alignment.centerRight:Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(c).size.width > 760 ? 680 : 620),
                  child: Padding(
                    padding: EdgeInsets.only(left:isUser?48:0,right:isUser?0:48,bottom:18),
                    child: Row(
                      crossAxisAlignment:CrossAxisAlignment.start,
                      mainAxisAlignment:isUser?MainAxisAlignment.end:MainAxisAlignment.start,
                      children:[
                        if(!isUser) Container(
                          width:32,height:32,
                          margin:const EdgeInsets.only(right:10,top:2),
                          decoration:BoxDecoration(color:MichishirubeTheme.accent,borderRadius:BorderRadius.circular(10)),
                          child:const Icon(Icons.route_outlined,color:Colors.white,size:19),
                        ),
                        Flexible(child: Container(
                          padding:const EdgeInsets.symmetric(horizontal:16,vertical:13),
                          decoration:BoxDecoration(
                            color:isUser?MichishirubeTheme.accent:MichishirubeTheme.paper,
                            borderRadius:BorderRadius.circular(17),
                            border:isUser?null:Border.all(color:const Color(0xFFE0D7CC)),
                          ),
                          child:Text(m.content,style:TextStyle(color:isUser?Colors.white:theme.colorScheme.onSurface,height:1.55)),
                        )),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    ),
    if(attachedName!=null) Padding(
      padding:const EdgeInsets.symmetric(horizontal:16),
      child:Align(alignment:Alignment.centerLeft,child:Chip(
        avatar:const Icon(Icons.attach_file,size:16),
        label:Text(attachedName!),
        onDeleted:()=>setState((){attachedName=null;attachedText=null;}),
      )),
    ),
    SafeArea(
      top:false,
      child: Padding(
        padding:const EdgeInsets.fromLTRB(12,6,12,12),
        child: Center(
          child: ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:760),
            child: Container(
              decoration:BoxDecoration(
                color:MichishirubeTheme.paper,
                borderRadius:BorderRadius.circular(20),
                border:Border.all(color:const Color(0xFFD8CEC1)),
                boxShadow:const [BoxShadow(color:Color(0x14000000),blurRadius:10,offset:Offset(0,3))],
              ),
              padding:const EdgeInsets.fromLTRB(6,6,6,6),
              child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
                IconButton(tooltip:'ファイル添付',onPressed:busy?null:_pickFile,icon:const Icon(Icons.attach_file)),
                IconButton(tooltip:'音声入力',onPressed:busy?null:_voice,icon:Icon(listening?Icons.mic:Icons.mic_none,color:listening?Colors.red:null)),
                Expanded(child:TextField(
                  controller:input,minLines:1,maxLines:6,
                  onTap:widget.onActivity,onChanged:(_)=>widget.onActivity(),
                  decoration:const InputDecoration(hintText:'今のモヤモヤを話してみてください',border:InputBorder.none,enabledBorder:InputBorder.none,focusedBorder:InputBorder.none,fillColor:Colors.transparent),
                )),
                const SizedBox(width:4),
                IconButton.filled(
                  onPressed:busy?null:_send,
                  icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.arrow_upward),
                ),
              ]),
            ),
          ),
        ),
      ),
    ),
  ]);
}
