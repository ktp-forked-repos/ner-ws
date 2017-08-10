<?
class Database {
  private $connection = null;

  function close() {
    mysql_close($this->connection);
  }
  function connect($host, $user, $pass, $db) {
    $this->connection = mysql_connect($host, $user, $pass);
    mysql_select_db($db, $this->connection);
    mysql_set_charset("utf8");
  }
  function fetch_array($query_result) {
    return mysql_fetch_array($query_result);
  }
  function query($query) {
    return mysql_query($query, $this->connection);
  }
}
?>