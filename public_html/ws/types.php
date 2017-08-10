<?php

class OperationResponse {
  public $status;
  public $msg;

  function __construct($status, $msg="") {
    $this->status = $status;
    $this->msg = $msg;
  }
}

?>
