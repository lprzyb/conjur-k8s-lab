<!DOCTYPE html>
<?php
  $secrets_source="ENVIRONMENT";
  $db_addr=getenv('DBADDR');
  $db_user=getenv('DBUSER');
  $db_pass=getenv('DBPASS');
  $ccp_fqdn=getenv('CCPFQDN');
  $appid=getenv('APPID');
  $query=getenv('QUERY');
  if(!empty($db_addr))
  {
    $host=$db_addr;
    $user=$db_user;
    $pass=$db_pass;
  }
  elseif(file_exists('/conjur/worlddb.json'))
  {
    $secrets_source="FILE /conjur/worlddb.json";
    $json_data = file_get_contents('/conjur/worlddb.json');
    $response_data = json_decode($json_data);
    $host = $response_data->dbaddr;
    $user = $response_data->dbuser;
    $pass = $response_data->dbpass;
  }
  elseif(file_exists('/etc/secret-volume'))
  {
    $secrets_source="K8S SECRETS";
    $host = file_get_contents('/etc/secret-volume/dbaddr');
    $user = file_get_contents('/etc/secret-volume/dbuser');
    $pass = file_get_contents('/etc/secret-volume/dbpass');
  }
  elseif(!empty($ccp_fqdn))
  {
    $secrets_source="AIMWebService";
    $ccp_url='https://'.$ccp_fqdn.'/AIMWebService/api/Accounts?AppID='.$appid.'&'.$query;
    $opts = array(
      'ssl'=>array(
        'verify_peer'=>false,
        'verify_peer_name'=>false
      )
    );
    $context = stream_context_create($opts);
    $json_data = file_get_contents($ccp_url, false, $context);
    $response_data = json_decode($json_data);
    $host = $response_data->Address;
    $user = $response_data->UserName;
    $pass = $response_data->Content;
  }
  else
  {
    exit('<h1>No database credentials configured!</h1>');
  }
  $port = '3306';
  $data = 'world';
  $chrs = 'utf8mb4';
  $attr = "mysql:host=$host;port=$port;dbname=$data;charset=$chrs";
  $opts =
  [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES => false,
  ];
  try
  {
    $pdo = new PDO($attr, $user, $pass, $opts);

    $query = "SELECT city.Name as City,country.name as Country,city.District,city.Population FROM city,country WHERE city.CountryCode = country.Code ORDER BY RAND() LIMIT 0,5";
    $result = $pdo->query($query);
    $rows = $result->fetchAll();

  }
  catch (PDOException $e)
  {
    $err_msg=$e->getMessage();
  }
  ?>
<html>
  <head>
    <meta http-equiv="refresh" content="30">
    <link rel="icon" href="https://www.cyberark.com/wp-content/themes/understrap-child/favicon.ico">
    <title>CyberArk Demo</title>
    <style>
      body { font-family: sans-serif; margin: 0; background: #f8f9fa; color: #212529; }
      header { background: #212529; padding: 12px 20px; }
      header img { height: 32px; }
      main { max-width: 700px; margin: 0 auto; padding: 24px 20px; text-align: center; }
      h1 { font-weight: 300; }
      table { width: 100%; border-collapse: collapse; margin: 16px 0; }
      th, td { padding: 6px 10px; border-bottom: 1px solid #dee2e6; text-align: left; }
      .card { background: #fff; border: 1px solid #dee2e6; border-radius: 6px; padding: 16px; text-align: left; margin: 16px 0; }
      .card p { margin: 4px 0; }
      .error { color: #dc3545; font-weight: bold; }
      .btn { display: inline-block; padding: 8px 16px; margin: 4px; border-radius: 4px; text-decoration: none; color: #fff; }
      .btn-primary { background: #0d6efd; }
      .btn-secondary { background: #6c757d; }
      footer { text-align: center; color: #6c757d; padding: 16px; font-size: 0.9em; }
    </style>
  </head>
  <body>
    <header>
      <img src="https://docs.cyberark.com/Product-Doc/OnlineHelp/Portal/Content/Resources/_TopNav/Images/Skin/lg-cyberark.svg">
    </header>
    <main>
      <h1>CyberArk Integration Demo</h1>
      <h2>Random World Cities</h2>
      <?php if(empty($err_msg)): ?>
      <table>
        <tr><th>City</th><th>District</th><th>Country</th><th>Population</th></tr>
        <?php foreach($rows as $row): ?>
        <tr>
          <td><?php echo $row['City']; ?></td>
          <td><?php echo $row['District']; ?></td>
          <td><?php echo $row['Country']; ?></td>
          <td><?php echo number_format($row['Population']); ?></td>
        </tr>
        <?php endforeach; ?>
      </table>
      <?php else: ?>
      <p class="error">DB ERROR: <?php echo $err_msg; ?></p>
      <?php endif; ?>

      <div class="card">
        <p>Host: <b><?php echo getenv('HOSTNAME'); ?></b></p>
        <p>Secret source: <b><?php echo $secrets_source; ?></b></p>
        <p>Connected to database <b><?php echo $data; ?></b> on <b><?php echo $host; ?></b>:<b><?php echo $port; ?></b></p>
        <p>Using username: <b><?php echo $user; ?></b> and password: <b><?php echo $pass; ?></b></p>
        <p>Last refreshed: <b><?php echo date('Y-m-d H:i:s'); ?></b> (auto-refreshes every 30s)</p>
      </div>

      <p>
        <a href="https://docs.cyberark.com" class="btn btn-primary">CyberArk Docs</a>
        <a href="https://cyberark-customers.force.com/mplace/s/" class="btn btn-secondary">CyberArk Marketplace</a>
      </p>
    </main>
    <footer>
      <p>A CyberArk demo by Joe Tan (joe.tan@cyberark.com)</p>
      <p>Added push to k8s secret demo by Huy Do (huy.do@cyberark.com)</p>
    </footer>
  </body>
</html>
