<?php
class Database {
  private $connection = null;

  function close() {
    mysql_close($this->connection);
  }
  function connect($host, $user, $pass, $db) {
    $this->connection = new mysqli($host, $user, $pass, $db);
  }
  function fetch_array($query_result) {
    return mysqli_fetch_array($query_result);
  }
  function query($query) {
    return $this->connection->query($query);
  }
}
?>
