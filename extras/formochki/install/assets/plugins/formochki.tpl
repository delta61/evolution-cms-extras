/**
 * Delta-Mailer
 *
 * Отправка писем с данными из форм
 *
 * @category    plugin
 * @version     3.7
 * @date        01.06.2022
 * @author      sergey.it@delta-ltd.ru
 * @internal    @events OnWebPageInit
 *
 *
 *
 */
$e = &$modx->event;
if ($e->name != 'OnWebPageInit' || ! isset($_GET['formochki'])) return;

$version = '3.6';

$upload_folder = 'assets/files/formochki/';

$archiver = 'tar'; // tar || zip

$forms = array(
	1 => array(
		'subject' => array('Подписка на новости','Подписка','Пользователь подписался','Subscribe'),
		'captcha'  => false,
		'mailto'   => trim($modx->getConfig('pvsk_email_from_subscribe_form')),
		'mailfrom' => false,
		'fromname' => false,
		'replyto'  => trim($modx->getConfig('pvsk_email_from_subscribe_form')),
		'cc'       => false,
		'bcc'      => false,
		'debug'    => false,
		
		'parent_for_mails' => 130,
		
		'events' => array(
			'before-email-is-sent' => array(
				array(
					'mode' => 'snippet',
					'snippet' => 'unisender-com',
					'prms' => array(
						'mode' => 'subscribe',
					),
					'waiting-for-successful-response' => 'ok',
				),
			),
		),
		
		'fields' => array(
			array(
				'label'    => array('Ваше имя','Имя','Контактное лицо','Name'),
				'name'     => 'fname',
				'type'     => 'text',
				'required' => false,
			),
			array(
				'label'    => array('Город','Ваш город','Из города','В городе','City'),
				'name'     => 'city',
				'type'     => 'text',
				'required' => false,
			),
			array(
				'label'    => array('Электронная почта','Почта','E-mail','Имэйл'),
				'name'     => 'email',
				'type'     => 'text',
				'required' => true,
				'required_text' => 'Укажите электронную почту',
			),
		),
	),
	
);

// -------------------------------------------------------------------------------

	function tarAddFile($tarfile, $file, $tofile)
	{
		if (is_dir($file)) {
			$v_typeflag = '5';
			$v_size = 0;
		} else {
			$v_typeflag = '';
			$v_size = filesize($file);
		}
		$v_size = sprintf('%11s ', DecOct($v_size));
		$v_mtime_data = filemtime($file);
		$v_mtime = sprintf('%11s', DecOct($v_mtime_data));
		$v_binary_data_first = pack('a100a8a8a8a12A12', $tofile, '', '', '', $v_size, $v_mtime);
		$v_binary_data_last = pack('a1a100a6a2a32a32a8a8a155a12', $v_typeflag, '', '', '', '', '', '', '', '', '');
		$v_checksum = 0;
		for ($i=0; $i<148; $i++) $v_checksum += ord(substr($v_binary_data_first,$i,1));
		for ($i=148; $i<156; $i++) $v_checksum += ord(' ');
		for ($i=156, $j=0; $i<512; $i++, $j++) $v_checksum += ord(substr($v_binary_data_last,$j,1));
		$v_checksum = sprintf('%6s ', DecOct($v_checksum));
		$v_binary_data = pack('a8', $v_checksum);
		$wrtres = fwrite($tarfile, $v_binary_data_first,148);
		if ( ! $wrtres) return false;
		$wrtres = fwrite($tarfile, $v_binary_data,8);
		if ( ! $wrtres) return false;
		$wrtres = fwrite($tarfile, $v_binary_data_last,356);
		if ( ! $wrtres) return false;
		$v_file = fopen($file,'rb');
		if ( ! $v_file) return false;
		while ( ! feof($v_file)) {
			$v_buffer = fread($v_file,512);
			if ( ! $v_buffer) break;
			$v_binary_data = pack('a512',$v_buffer);
			$wrtres = fwrite($tarfile, $v_binary_data);
		}
		fclose($v_file);
		if ( ! $wrtres) return false;
		return true;
	}
	function tarEmptyRow($tarfile)
	{
		return gzwrite($tarfile, pack('a512',''));
	}
	function tarOpen($tarfilepath, $mode='w')
	{
		$p_tar = fopen($tarfilepath, $mode.'b');
		return $p_tar ? $p_tar : false;
	}
	function tarClose($tarfile)
	{
		return fclose($tarfile);
	}

$errors = $events_errors = $events_errors_p = '';

$formid = intval($_POST['formid']);
$form   = $forms[$formid];

$pageid = intval($_POST['pageid']);

if ( ! is_array($form['fields'])) return;

foreach ($form['fields'] AS &$field) {
	$value = trim($_POST[$field['name'] ]);
	
	if ($field['type'] == 'textarea') {
		$value = str_replace("\r",'',$value);
		$value = '<br>'.str_replace("\n",'<br>',$value);
	}
	
	if ($field['type'] == 'file') {
		$value = $_FILES[$field['name']];
		if ( ! is_array($value) && ! is_array($value['name'])) continue;
		
		$archcreated = false;
		$archext = 'tar';
		$tarfile = false;
		$zip = false;
		if ($archiver == 'zip' && class_exists('ZipArchive')) {
			$archext = 'zip';
			$zip = new ZipArchive();
		}
		$folder = md5('_'.$_SERVER['REMOTE_ADDR']);
		$folder = $upload_folder.$folder.'/';
		if ( ! file_exists(MODX_BASE_PATH.$folder)) {
			mkdir(MODX_BASE_PATH.$folder,0755,true);
		}
		$archfile = md5(time().'-'.rand()).'.'.$archext;
		
		$dounlink = $hashes = array();
		$addedtoarch = false;
		foreach ($value['name'] AS $flkey => $flrow) {
			if ( ! $flrow || $value['error'][$flkey]) continue;
			if ($value['size'][$flkey] > 1024*1024*50) {
				$errors .= '<div>Файл слишком большой (>50 Мб)</div>';
				break;
			}
			$tmpfile = MODX_BASE_PATH.$folder.md5($value['name'][$flkey].time()).'_tmp';
			$res = move_uploaded_file($value['tmp_name'][$flkey],$tmpfile);
			if ( ! $res) {
				$errors .= '<div>Не удалось загрузить файл (01)</div>';
				break;
			}
			$dounlink[] = $tmpfile;
			$hash = md5_file($tmpfile);
			if ($hashes[$hash]) continue;
			$hashes[$hash] = true;
			
			if ( ! $archcreated) {
				$res = false;
				if ($archext == 'zip') {
					$res = $zip->open(MODX_BASE_PATH.$folder.$archfile,ZIPARCHIVE::CREATE | ZIPARCHIVE::OVERWRITE);
				} else {
					$res = tarOpen(MODX_BASE_PATH.$folder.$archfile);
					if ($res) $tarfile = $res;
				}
				if ( ! $res) {
					$errors .= '<div>Не удалось загрузить файл (03)</div>';
					break;
				}
				$archcreated = true;
			}
			
			$res = false;
			if ($archext == 'zip') {
				$res = $zip->addFile($tmpfile, $value['name'][$flkey]);
			} else {
				$res = tarAddFile($tarfile, $tmpfile, $value['name'][$flkey]);
			}
			if ( ! $res) {
				$errors .= '<div>Не удалось загрузить файл (04)</div>';
				break;
			}
			$addedtoarch = true;
		}
		if ( ! $addedtoarch || ! $archcreated) continue;
		if ($archext == 'zip') {
			$zip->close();
		} else {
			tarEmptyRow($tarfile);
			tarClose($tarfile);
		}
		foreach ($dounlink AS $unlnkrow) unlink($unlnkrow);
		$value = MODX_SITE_URL.$folder.$archfile;
		$fs = filesize(MODX_BASE_PATH.$folder.$archfile);
		$fs = round($fs/1024/1024,2);
		$value = '<a target="_blank" href="'.$value.'" rel="noopener">'.$value.'</a> ('.$fs.' Мб)';
	}
	
	if ($field['required'] === 'bool') {
	} elseif ($field['required'] === 'reg' && ! $value) {
	} elseif ($field['required'] && ! $value) {
		$errors .= '<div>'.($field['required_text'] ? $field['required_text'] : 'Заполните '.$field['label'][0]).'</div>';
	}
	
	$lbl = $field['label'][rand(0,count($field['label'])-1)];
	$mail_filds .= '<p><b>'.$lbl.':</b> '.$value.'</p>';
	
	$values[$field['name'] ] = $value;
}

if ( ! $errors) {
	$cntrl = round(intval($_POST['cntrl'])/1000);
	if ($cntrl < time()-60 || $cntrl > time()+60) $errors .= '<div>Ошибка! Обновите страницу и повторите отправку</div>';
}

if ($errors) {
	$p = '{"res":"er","text":"'.$errors.'"}';
	$modx->documentContent = $p;
	$modx->outputContent();
	exit();
}

if (
	1
	&& $form['events']
	&& $form['events']['before-email-is-sent']
	&& is_array($form['events']['before-email-is-sent'])
) {
	foreach ($form['events']['before-email-is-sent'] AS $ev) {
		if ($ev['mode'] == 'snippet') {
			$ev_snippet_prms = $ev['prms'];
			$ev_snippet_prms['formochki_form'] = $form;
			$ev_snippet_prms['formochki_values'] = $values;
			$ev_snippet_res = $modx->runSnippet($ev['snippet'], $ev_snippet_prms);
			if (
				$ev['waiting-for-successful-response']
				&& $ev_snippet_res['res'] !== $ev['waiting-for-successful-response']
			) {
				$events_errors .= '<p>— '.$ev_snippet_res['errtech'].'</p>';
			}
			continue;
		}
	}
}

if ($events_errors) {
	$events_errors_p .= '<br><p><b>Ошибки:</b></p>';
	$events_errors_p .= $events_errors.'<br>';
}

$ws = substr(MODX_SITE_URL,strpos(MODX_SITE_URL,'//')+2,-1);
$pageurl = $modx->makeUrl($pageid,'','','full');

$subject = $form['subject'][rand(0,count($form['subject'])-1)];
$subject .= ', '.$ws;

$mail = '<html><head><meta http-equiv="Content-Type" content="text/html; charset=utf-8" /><title>'.$subject.'</title></head><body><h2>'.$subject.'</h2>';
$mail .= '<p><b>Отправлено со страницы:</b> <a target="_blank" href="'.$pageurl.'">'.$pageurl.'</a></p>';
$mail .= $mail_filds;

$mail .= '<p><b>Дата и время сообщения:</b> '.date('d.m.Y, H:i').'</p>';
$mail .= $events_errors_p;
$mail .= '<p><i>Письмо отправлено в&nbsp;результате обращения клиента посредством формы обратной связи на&nbsp;вашем сайте. Не отвечайте на&nbsp;него &mdash; ваш ответ до клиента не дойдет.</i></p>';

$mail_bot .= '</body></html>';

$mail_2 = $mail;
$mail_2 .= $mail_bot;

if ($form['parent_for_mails']) {
	$pagetitle = $values['fname'].', '.$values['phone'];
	
	$alias = time().'-';
	$i = 0;
	do {
		$i++;
		$res = $modx->db->query("SELECT id FROM ".$modx->getFullTableName('site_content')."
			WHERE alias='".($alias.$i)."' LIMIT 1");
		if ($res && $modx->db->getRecordCount($res)) $flag = true;
		elseif ( ! $res) $flag = false;
	} while ($res && $flag);
	$alias .= $i;
	
	$mi = 1;
	$res = $modx->db->query("SELECT menuindex FROM ".$modx->getFullTableName('site_content')."
		WHERE parent='{$form['parent_for_mails']}' ORDER BY menuindex DESC LIMIT 1");
	if ($res && $modx->db->getRecordCount($res)) $mi = $modx->db->getValue($res)+1;
	
	$mail_2_q = $modx->db->escape($mail_2);
	$pagetitle_q = $modx->db->escape($pagetitle);

	$res = $modx->db->query("INSERT INTO ".$modx->getFullTableName('site_content')." SET
		pagetitle = '{$pagetitle_q}',
		alias = '{$alias}',
		parent = '{$form['parent_for_mails']}',
		content = '{$mail_2_q}',
		menuindex = '{$mi}',
		template = '0',
		published = '0',
		searchable = '0'
	");
	$mailpageid = $modx->db->getInsertId();
	$modx->clearCache('full');
}

if ($mailpageid) {
	$mailpage = $modx->makeUrl($mailpageid,$alias,'','full');
	$mail .= '<p><b>Копия письма в админке:</b> (для администратора)<br><a target="_blank" href="'.$mailpage.'">'.$mailpage.'</a></p>';
}

$mail .= $mail_bot;

// -------------------------------------------------------------------------------
if (1) {
	$modx->loadExtension('modxmailer');
	if ($form['debug']) {
		$modx->mail->SMTPDebug   = 2;
		$modx->mail->Debugoutput = 'html';
	}
	if ( ! $form['mailfrom']) {
		$form['mailfrom'] = $modx->config['smtp_username'];
	}
	$modx->mail->From     = $form['mailfrom'];
	$modx->mail->Sender   = $form['mailfrom'];
	if ($form['fromname']) $modx->mail->FromName = $form['fromname'];
	$modx->mail->isHTML(true);
	$modx->mail->Subject = $subject;
	$modx->mail->Body    = $mail;

	if ($form['replyto'] || $values['email']) {
		$modx->mail->addReplyTo($form['replyto'] ? $form['replyto'] : $values['email']);
	}
	if ($form['mailto']) {
		$form['mailto'] = explode(',', $form['mailto']);
		foreach ($form['mailto'] AS $row) {
			$modx->mail->addAddress(trim($row));
		}
	}
	if ($form['cc']) {
		$form['cc'] = explode(',', $form['cc']);
		foreach ($form['cc'] AS $row) {
			$modx->mail->addCC(trim($row));
		}
	}
	if ($form['bcc']) {
		$form['bcc'] = explode(',', $form['bcc']);
		foreach ($form['bcc'] AS $row) {
			$modx->mail->addBCC(trim($row));
		}
	}
	
	try {
		$result = $modx->mail->send();
		if ( ! $result) $res_err = $modx->mail->ErrorInfo;
	} catch (PHPMailerException $e) {
		$res_exc = $e->errorMessage();
	} catch (Exception $e) {
		$res_exc = $e->errorMessage();
	}
}
// -------------------------------------------------------------------------------

$buran_log = MODX_BASE_PATH.'_buran/log/sendmail/';
if ( ! file_exists($buran_log)) mkdir($buran_log,0755,true);
$log = fopen($buran_log.'formochki','ab');
$log_arr = array(
	time(),
);
if ($result) {
	$log_arr[] = '+';
	$p = '{"res":"ok","hideform":"true"}';
	
} else {
	$log_arr[] = '-';
	$log_arr[] = str_replace(array("\r","\n")," | ",$res_err);
	$log_arr[] = str_replace(array("\r","\n")," | ",$res_exc);
	$p = '{"res":"er","text":"<div>Ошибка! Повторите позже</div>"}';
}
if ($log) fputcsv($log,$log_arr,';');

$modx->documentContent = $p;
$modx->outputContent();
exit();
