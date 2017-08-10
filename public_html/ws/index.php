<?
require("config.php");
require("service.php");

$cfg_liner2_ws = "nerws.wsdl";

if ($_SERVER['REQUEST_METHOD'] == "GET") {
  echo "ok!";
 }
 else {
   ini_set('soap.wsdl_cache_enabled', 0);
   $server = new SoapServer($cfg_liner2_ws, array('cache_wsdl' => WSDL_CACHE_NONE,
						  'encoding' => 'UTF-8'));
   $server->setClass("LinerService");
   $server->handle();
 }

?>
