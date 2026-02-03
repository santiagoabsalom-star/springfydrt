class SearchRequest {


  String name;
  SearchRequest({
    required this.name
})
;
factory SearchRequest.fromJson(Map<String, dynamic> json){
return SearchRequest(name: json['name']);

}
}