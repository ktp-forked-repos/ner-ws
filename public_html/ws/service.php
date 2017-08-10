<?php

require("types.php");
require_once("config.php");
require_once("database.php");
require_once("log.php");

write_log("Connecting to the database...");
$database = new Database();
$database->connect($cfg_db_host, $cfg_db_user, $cfg_db_pass, $cfg_db_name);
write_log("connected.\n");

function ping_daemon($host, $port, $msg) {
    $socket = @socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
    if ($socket === false) {
      write_log("Could not create socket.\n");
      return false;
    }
    $result = @socket_connect($socket, $host, intval($port));
    if ($result === false) {
      write_log("Could not connect to daemon.\n");
      return false;
    }
	$msg .= "\n";
	$result = @socket_send($socket, $msg, strlen($msg), 0);
	if ($result === false) {
		write_log("Could not send data to socket.\n");
		return false;
	}
	$response = socket_read($socket, 64, PHP_NORMAL_READ);
	if ($response !== "OK\n") {
		write_log("Invalid daemon response: ".$response."\n");
		return false;
	}
    @socket_close($socket);
	return true;
}

function refresh_daemons_activity() {
	global $database, $cfg_daemon_ping_interval, $cfg_daemon_ping_timeout, $cfg_daemon_ping_max_unanswered;
	$query = "SELECT d.address, a.* FROM liner2_daemons AS d JOIN liner2_daemons_activity AS a";
	$query .= sprintf(" WHERE UNIX_TIMESTAMP(NOW()) - a.last_answered_ping > %d;", $cfg_daemon_ping_interval);
	$result = $database->query($query);
	while ($daemon = $database->fetch_array($result)) {
		// ping daemon
		list($daemon_host, $daemon_port) = explode(":", $daemon['address']);
		$response = ping_daemon($daemon_host, $daemon_port, "PING");

		if ($response === true) {
			// reset daemon activity data
			$database->query(sprintf("CALL daemon_reset_activity(%d);", $daemon['id']));
		}
		else {
			// report unanswered ping
			$database->query(sprintf("CALL daemon_unanswered_ping(%d);", $daemon['id']));

			// remove daemon? (if condition fulfilled)
			if ((time() - $daemon['last_answered_ping'] > $cfg_daemon_ping_timeout)
				&& ($daemon['unanswered_pings'] > $cfg_daemon_ping_max_unanswered)) {
				$database->query(sprintf("CALL unregister_daemon(%d);", $daemon['id']));
			}
		}
	}
}
refresh_daemons_activity();

class LinerService {

  function Annotate($input_format, $output_format, $model, $text) {
    global $database;
    write_log("Annotate called\n");

	// write request to database
    $ip = $_SERVER['REMOTE_ADDR'];
    $token = md5(microtime().substr($text, 0, 1)).md5(microtime().substr($text, 1, 2));
    $query = sprintf("CALL submit_request('%s', %d, '%s', '%s', '%s', '%s', '%s');",
		     $token, strlen($text), $input_format, $output_format, $model,
		     mysqli_real_escape_string($text), $ip);
    $database->query($query);

    // get daemon address
    write_log("Getting daemon address...\n");
    //$query = "SELECT id FROM liner2_daemons WHERE ready=1 LIMIT 1";
    $query = "SELECT address FROM liner2_daemons ORDER BY threads LIMIT 1";
    $result = $database->query($query);
    $daemons = $database->fetch_array($result);
    if (!$daemons) {
      write_log("No daemon working.\n");
      return new OperationResponse(1, $token);
    }
    list($daemon_host, $daemon_port) = explode(":", $daemons[0]);
    write_log(sprintf("Found daemon: host: %s, port: %s\n", $daemon_host, $daemon_port));

    // notify daemon
    write_log("notifying daemon...\n");
	ping_daemon($daemon_host, $daemon_port, "NOTIFY");

    return new OperationResponse(1, $token);
  }

  function GetResult($token) {
    global $database;
    write_log("GetResult called\n");
    $query = sprintf("SELECT state FROM liner2_requests WHERE token='%s';", $token);
    $result = $database->query($query);
    $request = $database->fetch_array($result);
    if (!$request) {
      return new SoapFault("Client", "Request not found.");
      //return new OperationResponse(0, "Request not found.");
    }
    
    if ($request[0] == "QUEUED")
      return new OperationResponse(1, "");
    elseif ($request[0] == "PROCESSING")
      return new OperationResponse(2, "");
    elseif ($request[0] == "READY") {
      $query = sprintf("SELECT request_id FROM liner2_requests WHERE token='%s';", $token);
      $result = $database->query($query);
      $request = $database->fetch_array($result);
      if (!$request) {
        return new SoapFault("Client", "Request not found.");
        //return new OperationResponse(0, "Request not found");
      }
      $request_id = $request[0];
      $database->query(sprintf("CALL retrieve_result(%d, @text);", $request_id));
      $result = $database->query("SELECT @text;");
      $data = $database->fetch_array($result);
      $text = $data[0];
      return new OperationResponse(3, $text);
    }
    elseif ($request[0] == "ERROR") {
      $query = sprintf("SELECT request_id FROM liner2_requests WHERE token='%s';", $token);
      $result = $database->query($query);
      $request = $database->fetch_array($result);
      if (!$request) {
       return new SoapFault("Client", "Request not found.");
  	    //return new OperationResponse(0, "Request not found");
      }
      $request_id = $request[0];
      $result = $database->query(sprintf("SELECT msg FROM liner2_requests_errors WHERE request_id=%d", 
					 $request_id));
      $data = $database->fetch_array($result);
      $msg = $data[0];
      return new SoapFault("Daemon", $msg);
      //return new OperationResponse(4, $msg);
    }
    elseif ($request[0] == "FINISHED")
      return new OperationResponse(5, "");
    else 
      return new SoapFault("Server", sprintf("Unknown request state: %s.", $request[0]));
  }

}

?>
