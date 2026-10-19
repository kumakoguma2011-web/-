class ProfileData {
  const ProfileData({this.freeText='',this.status='就業中（転職を検討中）',this.gender='未回答・回答しない',this.location='',this.personality='',this.relationships='',this.hobbies='',this.priority='ワークライフバランス・心の平穏'});
  final String freeText,status,gender,location,personality,relationships,hobbies,priority;
  Map<String,dynamic> toJson()=>{'free_text':freeText,'status':status,'gender':gender,'location':location,'personality':personality,'relationships':relationships,'hobbies':hobbies,'priority':priority};
  factory ProfileData.fromJson(Map<String,dynamic> x)=>ProfileData(freeText:x['free_text']?.toString()??'',status:x['status']?.toString()??'就業中（転職を検討中）',gender:x['gender']?.toString()??'未回答・回答しない',location:x['location']?.toString()??'',personality:x['personality']?.toString()??'',relationships:x['relationships']?.toString()??'',hobbies:x['hobbies']?.toString()??'',priority:x['priority']?.toString()??'ワークライフバランス・心の平穏');
}
class AnonRule { const AnonRule({required this.id,required this.original,required this.label}); final String id,original,label; factory AnonRule.fromJson(Map<String,dynamic> x)=>AnonRule(id:x['id'].toString(),original:x['original'].toString(),label:x['label'].toString()); }
class ChatMessage { const ChatMessage({required this.role,required this.content,required this.step}); final String role,content; final int step; factory ChatMessage.fromJson(Map<String,dynamic> x)=>ChatMessage(role:x['role'].toString(),content:x['content'].toString(),step:int.tryParse(x['step'].toString())??1); }

class ProfileSuggestionRecord {
  const ProfileSuggestionRecord({required this.text, required this.accepted, required this.createdAt});
  final String text;
  final bool accepted;
  final String createdAt;
  Map<String,dynamic> toJson()=>{'text':text,'accepted':accepted,'created_at':createdAt};
  factory ProfileSuggestionRecord.fromJson(Map<String,dynamic> x)=>ProfileSuggestionRecord(text:x['text'].toString(),accepted:x['accepted']==true,createdAt:x['created_at']?.toString()??'');
}
