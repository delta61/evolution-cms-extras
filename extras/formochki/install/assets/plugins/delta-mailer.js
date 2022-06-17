(function($){
	
	$(window).on('load',function(){
		$('.delta-mailer-form .frm_submit button').each(function(){
			$(this).parents('.delta-mailer-form').find('form').submit(function(){
				return false;
			});
			$(this).on('click',function(){
				var bttn = $(this);
				if (bttn.hasClass('frm_submit_load')) return;
				bttn.addClass('frm_submit_load');
	
				var box = bttn.parents('.delta-mailer-form');
				var frm = box.find('form');
	
				box.addClass('frm_loading');
	
				frm.find('input[name="cntrl"]').val(new Date().getTime());
	
				box.find('.frm_result').hide();
	
				var formData = new FormData(frm[0]);
				var ajaxresult = $.ajax({
					url: frm.attr('action')+'?delta-mailer-form-send',
					data: formData,
					processData: false,
					contentType: false,
					type: 'POST',
					dataType: 'JSON',
					cache: false
				}).done(function(data){
					bttn.removeClass('frm_submit_load');
					box.removeClass('frm_loading');
					var res = box.find('.frm_result_'+data.res);
					if (data.text) res.html(data.text);
					res.show();
					if (data.hideform == 'true') {
						frm.remove();
					}
					if (data.res == 'ok') {
						frm.find('.autosave').each(function(){
							var e = $(this);
							var nm = 'autosave_'+e.attr('id');
							localStorage.setItem(nm,'');
						});
					}
				});
				return;
			});
		});
	});
		
	$(document).ready(function(){
		var autosavetimer = new Array();
		$('.autosave').each(function(){
			var e = $(this);
			var nm = 'autosave_'+e.attr('id');
			e.val(localStorage.getItem(nm));
			e.on('keyup',function(){
				var e = $(this);
				var nm = 'autosave_'+e.attr('id');
				clearTimeout(autosavetimer[nm]);
				autosavetimer[nm] = setTimeout(function(){
					localStorage.setItem(nm,e.val());
				},500);
			});
		});
		$('.labelplaceholder .inp').focus(function(){
			$(this).parent().addClass('focus');
		});
		$('.labelplaceholder .inp').focusout(function(){
			if ($(this).val() == '') {
				$(this).parent().removeClass('focus');
			}
		});
		$('.labelplaceholder .inp').each(function(){
			if ($(this).val() != '') {
				$(this).parent().addClass('focus');
			}
		});
	});
	
	$(document).on('click','.myform .frm_file .frm_clear',function(){
		var e = $(this);
		var b = e.parents('.frm_file');
		b.remove();
	});
	
	$(document).on('change','.myform .frm_file input',function(){
		var e = $(this);
		var b = e.parents('.frm_file');
		if (
			b.hasClass('frm_input_multi')
			&& ! b.hasClass('focus')
		) {
			var id = e.attr('id');
			var cnt = b.parent().find('.frm_file').length;
			do {
				cnt++;
			} while ($('#'+id+'_'+cnt).length);
			var c = b.clone();
			c.find('input').attr('id',id+'_'+cnt).val(null);
			c.find('label').attr('for',id+'_'+cnt);
			c.appendTo(b.parent());
		}
		b.addClass('focus').find('label').text($(this)[0].files[0].name);
	});
	
})(jQuery);
