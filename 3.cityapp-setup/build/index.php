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

  $demo_methods =
  [
    'hardcode' => [
      'title' => 'Hardcoded Environment Variables',
      'blurb' => 'The DB password is a plain Kubernetes env var on the Deployment spec - visible to anyone who can read the pod spec or exec into the container. This is the baseline every other method here improves on.',
    ],
    'push-to-file' => [
      'title' => 'Conjur Secrets Provider: Push-to-File',
      'blurb' => 'An init container authenticates to Conjur with a JWT service account token, fetches the secret, and writes it to an in-memory volume as a JSON file the app reads at startup.',
    ],
    'push-to-k8s-secret' => [
      'title' => 'Conjur Secrets Provider: Push-to-K8s-Secret',
      'blurb' => 'Same Secrets Provider mechanism as push-to-file, but it writes the fetched value into a native Kubernetes Secret object instead - so any RBAC-permitted workload can consume it the standard k8s way.',
    ],
    'eso' => [
      'title' => 'External Secrets Operator (ESO)',
      'blurb' => 'ESO syncs the Conjur secret into a native Kubernetes Secret on a schedule, entirely outside this pod. The app itself has zero Conjur awareness - no ServiceAccount, no JWT, no sidecar.',
    ],
    'csi' => [
      'title' => 'Secrets Store CSI Driver',
      'blurb' => 'The Secrets Store CSI Driver mounts the secret live as a volume at pod startup, authenticating on the driver\'s behalf via an explicit identity - no JWT token is projected into this pod at all.',
    ],
  ];
  $demo_method = $demo_methods[getenv('DEMO_METHOD')] ?? null;
  ?>
<html>
  <head>
    <meta http-equiv="refresh" content="30">
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 32 32%22><rect width=%2232%22 height=%2232%22 rx=%226%22 fill=%22%23212529%22/><text x=%2216%22 y=%2223%22 font-size=%2220%22 font-family=%22sans-serif%22 font-weight=%22bold%22 fill=%22%236cc24a%22 text-anchor=%22middle%22>A</text></svg>">
    <title>Idira Demo</title>
    <style>
      body { font-family: sans-serif; margin: 0; background: #f8f9fa; color: #212529; }
      header { background: #212529; padding: 14px 20px; }
      .logo { color: #6cc24a; font-size: 1.3em; font-weight: 700; letter-spacing: 0.02em; text-decoration: none; }
      main { max-width: 700px; margin: 0 auto; padding: 24px 20px; text-align: center; }
      h1 { font-weight: 300; }
      table { width: 100%; border-collapse: collapse; margin: 16px 0; }
      th, td { padding: 6px 10px; border-bottom: 1px solid #dee2e6; text-align: left; }
      .card { background: #fff; border: 1px solid #dee2e6; border-radius: 6px; padding: 16px; text-align: left; margin: 16px 0; }
      .card p { margin: 4px 0; }
      .card.story { border-left: 4px solid #6cc24a; }
      .card.story h3 { margin: 0 0 6px; }
      .card.story p { margin: 0; color: #495057; }
      .error { color: #dc3545; font-weight: bold; }
      .btn { display: inline-block; padding: 8px 16px; margin: 4px; border-radius: 4px; text-decoration: none; color: #fff; }
      .btn-primary { background: #0d6efd; }
      .btn-secondary { background: #6c757d; }
      footer { text-align: center; color: #6c757d; padding: 16px; font-size: 0.9em; }
    </style>
  </head>
  <body>
    <header>
      <span class="logo">Idira</span>
    </header>
    <main>
      <h1>Idira Integration Demo</h1>
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

      <?php if($demo_method): ?>
      <div class="card story">
        <h3><?php echo htmlspecialchars($demo_method['title']); ?></h3>
        <p><?php echo htmlspecialchars($demo_method['blurb']); ?></p>
      </div>
      <?php endif; ?>

      <div class="card">
        <p>Host: <b><?php echo getenv('HOSTNAME'); ?></b></p>
        <p>Secret source: <b><?php echo $secrets_source; ?></b></p>
        <p>Connected to database <b><?php echo $data; ?></b> on <b><?php echo $host; ?></b>:<b><?php echo $port; ?></b></p>
        <p>Using username: <b><?php echo $user; ?></b> and password: <b><?php echo $pass; ?></b></p>
        <p>Last refreshed: <b><?php echo date('Y-m-d H:i:s'); ?></b> (auto-refreshes every 30s)</p>
      </div>

      <p>
        <a href="https://docs.cyberark.com" class="btn btn-primary">Idira Docs</a>
        <a href="https://cyberark-customers.force.com/mplace/s/" class="btn btn-secondary">Idira Marketplace</a>
      </p>
    </main>
    <footer>
      <p>An Idira demo by Joe Tan (joe.tan@cyberark.com)</p>
      <p>Added push to k8s secret demo by Huy Do (huy.do@cyberark.com)</p>
    </footer>
  </body>
</html>
