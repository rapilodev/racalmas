/*
function hideImageDetails(id,filename){
	try{$('#img_editor').dialog('close');}catch(e){}

	$("#"+id).load('image.cgi?show='+filename+'&template=image_single.html');
	return false;
}

function saveImage(id, filename) {
	var url='image.cgi?save_image='+filename;
	if (url!='') $.post(
		url, 
		$("#save_img_"+id).serialize(), 
		function(data){
			hideImageDetails('img_'+id, filename);
			
		} 
	);
	return false;
}

function deleteImage(id, filename) {
	$("#"+id).load('image.cgi?delete_image='+filename);
	hideImageDetails('img_'+id, filename);
	$("#"+id).hide('drop');
	return false;
}

function showImageUrl(id){
	var el=document.getElementById(id);
	var input_id=id+'_input';
	var text='<input id="'+input_id+'" value="{{thumbs/'+id+'|title}}" title="3fach-Klick zum Markieren!">';
	if (el.innerHTML==text){
		el.innerHTML='';
	}else{
		el.innerHTML=text;
		var input=document.getElementById(input_id);
		input.focus();
		input.select();
		input.createTextRange().execCommand("Copy");
	}
	return false;
}

*/
