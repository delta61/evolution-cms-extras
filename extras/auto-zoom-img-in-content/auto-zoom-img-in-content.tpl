/**
 * Увеличение картинок
 *
 * @category    plugin
 * @version     1.0
 * @date        05.10.2023
 * @author      sergey.it@delta-ltd.ru
 * @internal    @events OnWebPagePrerender
 *
 *
 *
 */

$e = &$modx->event;
if ($e->name != 'OnWebPagePrerender') return;
    
$html = $modx->documentOutput;

$pmtchres = preg_match_all("/<noscript class=\"autoimgzoom-1\"><\/noscript>(.*)<noscript class=\"autoimgzoom-2\"><\/noscript>/Us", $html, $mtchs);
if ( ! $pmtchres) return;

$pmtchres = preg_match_all("/<img\s(?:(([^>]*)src=(\"(.*)\"|'(.*)')|))([^>]*)>/isU", $mtchs[1][0], $mtchs);
if ( ! $pmtchres) return;

foreach ($mtchs[0] AS $key => $row) {
    $src = $mtchs[4][$key];
    $row2 = str_replace(' src=', ' class="lazyload" loading="lazy" data-src=', $row);
    $html = str_replace($row, '<a data-fancybox="" href="'.$src.'">'.$row2.'</a>', $html);
}

$modx->documentOutput = $html;
return;
