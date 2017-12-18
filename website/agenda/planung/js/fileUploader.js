/*
*	Class: fileUploader
*	Use: Upload multiple files the jQuery way
*	Author: John Lanz (http://pixelcone.com)
*	Version: 1.0
*/

(function($) {
	$.fileUploader = {version: '1.1'};
	$.fn.fileUploader = function(config){
		
		config = $.extend({}, {
			limit: '1',
			imageLoader: '',
			buttonUpload: '#pxUpload',
			buttonClear: '#pxClear',
			successOutput: 'File Uploaded',
			errorOutput: 'Failed',
			inputName: 'image',
			inputSize: 30,
			allowedExtension: 'jpg|jpeg|gif|png',
			callback: function() {},
			url: window.location.href
		}, config);
		
		var itr = 0; //number of files to uploaded
		var $limit = 1;
		
		//public function
		$.fileUploader.change = function(e){
			var fname = px.validateFile( $(e).val() );
			if (fname == -1){
				alert ("Invalid file!");
				$(e).val("");
				return false;
			}
			$('#px_button input').removeAttr("disabled");
			var imageLoader = '';
			if ($.trim(config.imageLoader) != ''){
				imageLoader = '<img src="'+ config.imageLoader +'" alt="uploader" />';
			}
			var display = '<div class="uploadData" id="pxupload'+ itr +'_text" title="pxupload'+ itr +'">' + 
				'<div class="close">&nbsp;</div>' +
				'<span class="fname">'+ fname +'</span>' +
				'<span class="loader" style="display:none">'+ imageLoader +'</span>' +
				'<div class="status"></div>'+
				'</div>';
			
			$("#px_display").append(display);
			if (config.limit == '' || $limit < config.limit) {
				px.appendForm();
			}
			$limit++;
			$(e).hide();
			//px.upload();

		}
		
		// To exactly match $("a.foo").live("click", fn), for example, you can write $(document).on("click", "a.foo", fn). 
		// $(".close").live("click", function(){
		$(document).on("click", ".close", function(){
			$limit--;
			if ($limit == config.limit) {
				px.appendForm();
			}
			var id = "#" + $(this).parent().attr("title");
			$(id+"_frame").remove();
			$(id).remove();
			$(id+"_text").fadeOut("slow",function(){
				$(this).remove();
			});
			return false;
		});
		
		//$(config.buttonClear).click(function(){
		$(document).on("click", "config.buttonClear", function(){
			$("#px_display").fadeOut("slow",function(){
				$("#px_display").html("");
				$("#pxupload_form").html("");
				itr = 0;
				$limit = 1;
				px.appendForm();
				$('#px_button input').attr("disabled","disabled");
				$(this).show();
			});
		});
		
		//private function
		var px = {
			init: function(e){
				var form = $(e).parents('form');
				px.formAction = $(form).attr('action');

				$(form).before(' \
					<div id="pxupload_form"></div> \
					<div id="px_display"></div> \
					<div id="px_button"></div> \
				');
				$(config.buttonUpload+','+config.buttonClear).appendTo('#px_button');
				if ( $(e).attr('name') != '' ){
					config.inputName = $(e).attr('name');
				}
				if ( $(e).attr('size') != '' ){
					config.inputSize = $(e).attr('size');
				}
				$(form).hide();
				$(config.buttonUpload).click(function(){
					px.upload()
				})

				this.appendForm();
			},
			appendForm: function(){
				itr++;
				var formId = "pxupload" + itr;
				var iframeId = "pxupload" + itr + "_frame";
				var inputId = "pxupload" + itr + "_input";
				var contents = 
				'<form method="post" id="'+ formId +'" action="'+ px.formAction +'" enctype="multipart/form-data" target="'+ iframeId +'">' 
				+'<br/>'+loc['label_name']+'<br /><input name="name" />'
				+'<br/>'+loc['label_description']+'<br /><textarea name="description" rows="3" cols="40"></textarea>'
				;
				if (studio_id != null) contents+='<input type="hidden" name="studio_id" value="'+studio_id+'">';
				if (project_id != null) contents+='<input type="hidden" name="project_id" value="'+project_id+'">';
				contents+=
				'<input type="file" name="'+ config.inputName +'" id="'+ inputId +'" class="pxupload" size="'+ config.inputSize +'" onchange="$.fileUploader.change(this);" />' 
				+'<input name="action" value="upload" type="hidden"/>'
				+'</form>'
				+'<iframe id="'+ iframeId +'" name="'+ iframeId +'" src="about:blank" style="display:none"></iframe>';
				
				$("#pxupload_form").append( contents );
			},
			validateFile: function(file) {
				if (file.indexOf('/') > -1){
					file = file.substring(file.lastIndexOf('/') + 1);
				}else if (file.indexOf('\\') > -1){
					file = file.substring(file.lastIndexOf('\\') + 1);
				}
				//var extensions = /(.jpg|.jpeg|.gif|.png)$/i;
				var extensions = new RegExp(config.allowedExtension + '$', 'i');
				if (extensions.test(file)){
					return file;
				} else {
					return -1;
				}
			},

			upload: function(){
				if (itr > 0){
					$('#px_button input').attr("disabled","disabled");
					$("#pxupload_form form").each(function(){
						e = $(this);
						var id = "#" + $(e).attr("id");
						var input_id = id + "_input";
						var input_val = $(input_id).val();
						if (input_val != ""){
							$(id + "_text .status").text("Uploading...");
							$(id + "_text").css("background-color", "#FFF0E1");
							$(id + "_text .loader").show();
							$(id + "_text .close").hide();
						
							$(id).submit();
							$(id +"_frame").load(function(){
								$(id + "_text .loader").hide();
								up_output = $(this).contents().find("#output").html();
                                var success=0;
								if (up_output == "success"){
                                    success=1;
									$(id + "_text").css("background-color", "#F0F8FF");
									up_output = config.successOutput;
									px.redirect();
								}else{
									$(id + "_text").css("background-color", "#FF0000");
									up_output = config.errorOutput;
								}

                                //custom code
								up_output += '<br />' + $(this).contents().find("#message").html();
								//alert($(this).contents())
								//console.log(JSON.stringify($(this).contents()));
								$(id + "_text .status").html(up_output);

                                if(success==1){
                                    var image_id=$(this).contents().find("#upload_image_id").html();
                                    var filename=$(this).contents().find("#upload_image_filename").html();
                                    var title   =$(this).contents().find("#upload_image_title").html();
                                    var quote="'";
                                    
                                    //remove existing image from list
                                    $('#imageList div.images #img_'+image_id).remove();
                                    //add image to list
                                    $('#imageList div.images').prepend(
                                        '<div id="img_'+image_id+'" class="image" '
                                        +' onclick="imageAction('+quote+filename+quote+');return false;" '
                                        +' title="'+title+'" '
                                        +' style="background-image:url('+quote+'/agenda_files/media/thumbs/'+filename+quote+')"'
                                        +'>'
                                        +'    <div class="label">'+title+'</div>'
                                        +'</div>'
                                    );
                                }
                                //end of custom code
								$(e).remove();
								$(config.buttonClear).removeAttr("disabled");
								config.callback($(this));
							});
						}
					});
				}
			},

			redirect: function(){
				//window.location.replace(config.url)
				//$('#pxupload_form').append('<form id="redirect" method="GET" action="'+config.url+'" />');
				//$('#redirect').submit();
			}


		}
		
		px.init(this);
		
		return this;
	}
})(jQuery);
