<!DOCTYPE html>
<%@ taglib prefix="spring" uri="http://www.springframework.org/tags"%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core"%>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt"%>
<html>
  <head>
    <meta http-equiv="refresh" content="30">
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 32 32%22><rect width=%2232%22 height=%2232%22 rx=%226%22 fill=%22%23212529%22/><text x=%2216%22 y=%2223%22 font-size=%2220%22 font-family=%22sans-serif%22 font-weight=%22bold%22 fill=%22%236cc24a%22 text-anchor=%22middle%22>A</text></svg>">
    <title>CyberArk Demo</title>
    <style>
      body { font-family: sans-serif; margin: 0; background: #f8f9fa; color: #212529; }
      header { background: #212529; padding: 14px 20px; }
      .logo { color: #fff; font-size: 1.3em; font-weight: 700; letter-spacing: 0.02em; text-decoration: none; }
      .logo span { color: #6cc24a; }
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
      <span class="logo">Cyber<span>Ark</span></span>
    </header>
    <main>
      <h1>CyberArk Integration: CityApp SpringBoot Demo</h1>
      <h2>Random World Cities</h2>
      <c:if test="${!empty cities}">
      <table>
        <tr><th>City</th><th>District</th><th>Country</th><th>Population</th></tr>
        <c:forEach items="${cities}" var="c">
        <tr>
          <td>${c.city}</td>
          <td>${c.district}</td>
          <td>${c.country}</td>
          <td><fmt:formatNumber value="${c.population}"/></td>
        </tr>
        </c:forEach>
      </table>
      </c:if>
      <c:if test="${empty cities}">
      <p class="error">DB ERROR: Query is empty</p>
      </c:if>

      <%
        String conjur = System.getenv("CONJUR_APPLIANCE_URL");
        String secretSource;
        String dbuser;
        String dbpass;
        String dbHostDisplay;
        if (conjur == null) {
          secretSource = "ENVIRONMENT";
          dbuser = System.getenv("DB_USER");
          dbpass = System.getenv("DB_PASS");
          dbHostDisplay = System.getenv("DB_HOST") + ":" + System.getenv("DB_PORT");
        } else {
          secretSource = "CONJUR: " + conjur;
          dbuser = "getting from " + System.getenv("CONJUR_MAPPING_DB_USER");
          dbpass = "getting from " + System.getenv("CONJUR_MAPPING_DB_PASS");
          dbHostDisplay = "resolved via Conjur SDK at startup";
        }
      %>
      <div class="card">
        <p>Host: <b><%= System.getenv("HOSTNAME") %></b></p>
        <p>Secret source: <b><%= secretSource %></b></p>
        <p>Connected to database <b><%= System.getenv("DB_NAME") %></b> on <b><%= dbHostDisplay %></b></p>
        <p>Using username: <b><%= dbuser %></b> and password: <b><%= dbpass %></b></p>
      </div>

      <p>
        <a href="https://docs.cyberark.com" class="btn btn-primary">CyberArk Docs</a>
        <a href="https://cyberark-customers.force.com/mplace/s/" class="btn btn-secondary">CyberArk Marketplace</a>
      </p>
    </main>
    <footer>
      <p>A CyberArk demo by Joe Tan (joe.tan@cyberark.com)</p>
      <p>Converting to SpringBoot by Huy Do (huy.do@cyberark.com)</p>
    </footer>
  </body>
</html>
