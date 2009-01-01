<?php
require_once 'spyc.php5';
define('MOVIES_PER_PAGE', 20);
$movies = syck_load(file_get_contents('cache/downloaded.yml'));
$page = $_GET['page'];
$page_count = ceil(count($movies) / MOVIES_PER_PAGE);
if (!($page>=1 && $page<=$page_count)) {
  $page = 1;
}
$movies_page_index = ($page-1) * MOVIES_PER_PAGE;
?>
<html>
<head>
<title>haccho</title>
<style type="text/css">
* {line-height: 1em;}
h2 {font-size:10pt; display:inline;}
.keywords {font-size:8pt; display:inline;}
.title {margin-top:10px;}
</style>
</head>
<body>
<h1>haccho</h1>
<div class="section">
<? for ($i=0; $i<MOVIES_PER_PAGE && ($i+kmovies_page_index)<count($movies); $i++) { ?>
  <? $m = $movies[$i + $movies_page_index] ?>
  <div class="subsection">
    <div class="title">
      <h2><?= $m['title'] ?></h2>
      <? $keywords = join($m['keywords'], ', ') ?>
      <p class="keywords"><?= $keywords ?></p>
    </div>
    <div class="image_box">
      <a href="<?= $m['uri'] ?>"><img src="cache/<?= $m['package_image'] ?>"/></a>
    </div>
    <? if ($m['thumb_images']) { ?>
      <div class="thumb_box">
      <? foreach ($m['thumb_images'] as $th) { ?>
        <img src="cache/<?= $th ?>"/>
      <? } ?>
      </div>
    <? } ?>
  </div>
<? } ?>
</div>
<? if ($page<$page_count) { ?>
  <p><a href="?page=<?= $page+1 ?>" rel="next">next</a></p>
<? } ?>
</body>
</html>
