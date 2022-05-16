<?php
/**
 * Delta-CBR-Kurs-Valut
 *
 * ЦБР Курс Валют
 *
 * @category  snippet
 * @version   2.1
 * @date      16.05.2022
 * @author    sergey.it@delta-ltd.ru
 *
 */

$cbr_kurs_code = array(
	'840' => 'usd',
	'978' => 'eur',
);
$kurs_def = array(
	'rub' => 1,
	'usd' => 100,
	'eur' => 100,
);

$nacenka = intval(trim($modx->getConfig('client_cbrf_nacenka')));
$nacenka = 1 + ($nacenka ? $nacenka/100 : 0);

$kurs_file = MODX_BASE_PATH.'cbr/cbr_kurs';
$kurs_file_dt = file_exists($kurs_file) ? filectime($kurs_file) : 0;

if (
	time() - $_SESSION['cbr_kurs']['cbr_reqst'] > 60*60
	&& (
		! file_exists($kurs_file)
		|| (
			time() - $kurs_file_dt > 60*60*12
			&& date('H') > 12 && date('H') < 18
		)
	)
) {
	$_SESSION['cbr_kurs']['cbr_reqst'] = time();
	$cbr_kurs_flag = false;
	$cbr_kurs_arr = array();
	$cbr_kurs_curr = file_get_contents('https://www.cbr.ru/scripts/XML_daily.asp');
	if ($cbr_kurs_curr) {
		$fh = fopen($kurs_file.'.xml','wb');
		if ($fh) {
			fwrite($fh, $cbr_kurs_curr);
			fclose($fh);
		}
		
		$cbr_kurs_xml = simplexml_load_string($cbr_kurs_curr);
		if ($cbr_kurs_xml) {
			foreach ($cbr_kurs_xml->Valute AS $row) {
				$num = intval($row->NumCode);
				$kursnm = $cbr_kurs_code[$num];
				if ( ! $kursnm) continue;
				$cbr_kurs_flag = true;
				$cbr_kurs_arr[$kursnm] = floatval(str_replace(',','.',$row->Value));
			}
		}
	}
	if ($cbr_kurs_flag) {
		$cbr_kurs_srlz = serialize($cbr_kurs_arr);
		$fh = fopen($kurs_file,'wb');
		if ($fh) {
			fwrite($fh, $cbr_kurs_srlz);
			fclose($fh);
		}
	}
}

$kurs_arr_res = array();
if (
	$_SESSION['cbr_kurs']['dt']
	&& time() - $_SESSION['cbr_kurs']['dt'] < 60*60
	&& $nacenka == $_SESSION['cbr_kurs']['nacenka']
) {
	$kurs_arr_res = $_SESSION['cbr_kurs']['vl'];
	
} elseif (file_exists($kurs_file)) {
	$kurs_file_val = '';
	$fh = fopen($kurs_file,'rb');
	if ($fh) while ( ! feof($fh)) $kurs_file_val .= fread($fh,1024*256);
	if ($kurs_file_val) $kurs_file_val = unserialize($kurs_file_val);
	if (
		$kurs_file_val
		&& is_array($kurs_file_val)
		&& $kurs_file_val['usd']
	) {
		foreach ($kurs_file_val AS $key => $row) {
			$kurs_file_val[$key] = $row * $nacenka;
		}
		$kurs_arr_res = $kurs_file_val;
	} else {
		$kurs_arr_res = $kurs_def;
		if (time() - $kurs_file_dt > 60*60) {
			unlink($kurs_file);
		}
	}
	$_SESSION['cbr_kurs'] = array(
		'dt' => time(),
		'vl' => $kurs_arr_res,
		'nacenka' => $nacenka,
	);
} else {
	$kurs_arr_res = $kurs_def;
}

if ($type) return $kurs_arr_res[$type] ? $kurs_arr_res[$type] : false;
else return print_r($kurs_arr_res,1);

return;
