<?php
define('MOVIES_PER_PAGE', 20);
$pit = syck_load(file_get_contents('../secure/default.yml'));
$pit = $pit['haccho_mysql'];
$dsn = 'mysql:host=localhost;port=3306;dbname=haccho';
$db = new PDO($dsn, $pit['username'], $pit['password']);

$page = $_GET['page'];
$page_count = ceil(count($movies) / MOVIES_PER_PAGE);
if (!($page>=1 && $page<=$page_count)) {
  $page = 1;
}
$movies_page_index = ($page-1) * MOVIES_PER_PAGE;

$st     = $db->prepare('SELECT * FROM entries LIMIT '.$movies_page_index.', '.MOVIES_PER_PAGE);
$res    = $st->execute();
$movies = $st->fetchAll();

?>
<html>
<head>
<title>haccho</title>
<style type="text/css">
* {line-height: 1em;}
h2 {font-size:10pt; display:inline;}
.keywords {font-size:8pt; display:inline;}
.entry-title {margin-top:10px;}
</style>
</head>
<body>
<h1>haccho</h1>
<div class="section">
<? for ($i=0; $i<MOVIES_PER_PAGE && ($i+$movies_page_index)<count($movies); $i++) { ?>
  <?
    $m = $movies[$i + $movies_page_index];
    $cid = $m['cid'];
    $pre = substr($cid, 0, 3);
    $package_image = "cache/$pre/$cid.jpg";
    $thumb_images  = glob("cache/$pre/$cid-*.jpg");
    $uri = "http://www.dmm.co.jp/rental/-/detail/=/cid=$cid/";
  ?>
  <div class="hentry">
    <div class="entry-title">
      <h2><?= $m['title'] ?></h2>
      <p class="keywords"><?= $m['keywords'] ?></p>
    </div>
    <div class="entry-content">
      <div class="image-box">
        <a href="<?= $uri ?>" rel="bookmark"><img src="<?= $package_image ?>"/></a>
      </div>
      <? if ($thumb_images) { ?>
        <div class="thumb-box">
        <? foreach ($thumb_images as $th) { ?>
          <img src="<?= $th ?>"/>
        <? } ?>
        </div>
      <? } ?>
    </div>
  </div>
<? } ?>
</div>
<? if ($page<$page_count) { ?>
  <p><a href="?page=<?= $page+1 ?>" rel="next">next</a></p>
<? } ?>
</body>
</html>
