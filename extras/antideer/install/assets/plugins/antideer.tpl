/**
 * Delta-Antideer
 *
 * Антиолень
 *
 * @category    plugin
 * @version     6.1
 * @date        02.01.2018
 * @author      sergey.it@delta-ltd.ru
 * @internal    @events OnBeforeDocFormSave,OnBeforeDocFormDelete,OnBeforeChunkFormSave,OnBeforeChunkFormDelete,OnBeforeSnipFormSave,OnBeforeSnipFormDelete,OnBeforeTempFormSave,OnBeforeTempFormDelete,OnBeforePluginFormSave,OnBeforePluginFormDelete,OnBeforeTVFormSave,OnBeforeTVFormDelete
 *
 *
 *
 */

$e= &$modx->event;
$mid= intval($e->params['id']);
if( ! $mid) return;

if($e->name == "OnBeforeDocFormSave" || $e->name == "OnBeforeDocFormDelete")
{
	$tbs[]= 'site_content';
	$tbs[]= 'site_tmplvar_contentvalues';
}

if($e->name == "OnBeforeChunkFormSave" || $e->name == "OnBeforeChunkFormDelete")
	$tbs[]= 'site_htmlsnippets';

if( $e->name == "OnBeforeSnipFormSave" || $e->name == "OnBeforeSnipFormDelete" )
	$tbs[]= 'site_snippets';

if( $e->name == "OnBeforeTempFormSave" || $e->name == "OnBeforeTempFormDelete" )
	$tbs[]= 'site_templates';

if( $e->name == "OnBeforePluginFormSave" || $e->name == "OnBeforePluginFormDelete" )
	$tbs[]= 'site_plugins';

if( $e->name == "OnBeforeTVFormSave" || $e->name == "OnBeforeTVFormDelete" )
	$tbs[]= 'site_tmplvars';


if( ! is_array($tbs)) return;
foreach($tbs AS $tb)
{
	$tbf= $modx->getFullTableName($tb);
	$tb_= $modx->getFullTableName('aa_'.$tb);

	$rr= $modx->db->query("SHOW CREATE TABLE ".$tbf);
	if( ! $rr || ! $modx->db->getRecordCount($rr)) continue;
	$sql= $modx->db->getRow($rr);
	$sql= $sql['Create Table'];

	preg_match_all("/^  (`.*`) .*,$/Um", $sql, $fields);
	$fields= implode(',', $fields[1]);
	
	
	$rr= $modx->db->query("SHOW TABLES LIKE '%aa_{$tb}'");
	if( ! $rr || ! $modx->db->getRecordCount($rr))
	{
		$sql= explode("\n", $sql);
		if( ! is_array($sql)) continue;
		$qr= '';
		foreach($sql AS $rw)
		{
			$rw= trim($rw);
			if(strpos($rw, "`") !== 0 || strpos($rw, "`id`") === 0) continue;
			$qr .= $rw ."\n";
		}
		if( ! $qr) continue;

		$qr2= "CREATE TABLE IF NOT EXISTS ". $tb_;
		$qr2 .= " (" ."\n";
		$qr2 .= "`idm` int(10) NOT NULL AUTO_INCREMENT,". "\n";
		$qr2 .= "`id` int(10) NOT NULL,". "\n";
		$qr2 .= $qr;
		$qr2 .= "`tm` bigint(20) NOT NULL,". "\n";
		$qr2 .= "PRIMARY KEY (`idm`)" ."\n";
		$qr2 .= ") ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1";

		$modx->db->query($qr2);
	}
	
	
	if($tb != 'site_tmplvar_contentvalues')
	{
		$rr= $modx->db->query("INSERT INTO {$tb_} ({$fields} ,`tm`)
			SELECT *, UNIX_TIMESTAMP() AS `tm`
			FROM {$tbf} WHERE id={$mid} LIMIT 1");
		
	}else{
		$rr= $modx->db->query("SELECT id FROM ".$modx->getFullTableName('site_tmplvars'));
		if( ! $rr || ! $modx->db->getRecordCount($rr)) continue;
		while($tv= $modx->db->getRow($rr))
		{
			$modx->db->query("INSERT INTO {$tb_} ({$fields} ,`tm`)
				SELECT *, UNIX_TIMESTAMP() AS `tm`
				FROM {$tbf}
				WHERE contentid={$mid} AND tmplvarid={$tv['id']} LIMIT 1");
		}
	}
}
