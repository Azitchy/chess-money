<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Chess Admin Panel</title>
  <style>
    :root{
      --bg:#edf1f5;
      --sidebar:#2f3742;
      --sidebar-soft:#3a4451;
      --text:#1f2937;
      --muted:#6b7280;
      --white:#fff;
      --line:#dce3ec;
      --blue:#1d72f3;
      --green:#14a157;
      --yellow:#f5bc02;
      --red:#df3f52;
      --shadow:0 12px 24px rgba(8,15,32,.08);
    }
    *{box-sizing:border-box}
    body{margin:0;font-family:"Segoe UI",Tahoma,Verdana,sans-serif;background:var(--bg);color:var(--text)}
    a{text-decoration:none;color:inherit}
    .app{display:flex;min-height:100vh}
    .sidebar{width:260px;background:var(--sidebar);color:#d1d8e0;padding:14px 12px;position:sticky;top:0;height:100vh}
    .brand{display:flex;align-items:center;gap:10px;padding:8px 10px;border-bottom:1px solid rgba(255,255,255,.08);margin-bottom:10px}
    .brand-badge{width:28px;height:28px;border-radius:50%;background:#1f2630;display:grid;place-items:center;font-weight:700}
    .menu-title{font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:#9ba7b8;padding:12px 10px 6px}
    .menu a{display:block;padding:10px;border-radius:8px;color:#d7dee8;font-size:14px}
    .menu a:hover,.menu a.active{background:var(--sidebar-soft);color:#fff}
    .main{flex:1;display:flex;flex-direction:column;min-width:0}
    .topbar{height:58px;background:#fff;border-bottom:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;padding:0 18px}
    .topbar-title{font-size:14px;color:var(--muted)}
    .logout-btn{background:#f3f5f8;border:1px solid var(--line);border-radius:8px;padding:8px 12px;cursor:pointer}
    .content{padding:20px}
    .content-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:16px}
    .content-header h1{font-size:28px;margin:0}
    .crumb{color:var(--muted);font-size:13px}
    .card{background:#fff;border:1px solid var(--line);border-radius:10px;box-shadow:var(--shadow);padding:16px}
    .flash{padding:12px 14px;border-radius:8px;margin-bottom:14px;font-size:14px}
    .ok{background:#dcfce7;color:#166534}
    .err{background:#fee2e2;color:#991b1b}
    .stats-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:16px}
    .stat-card{color:#fff;border-radius:8px;padding:14px 14px 10px;position:relative;overflow:hidden}
    .stat-card h3{font-size:34px;margin:0 0 4px;line-height:1}
    .stat-card p{margin:0;font-size:14px}
    .stat-card .more{display:block;margin-top:12px;padding-top:8px;border-top:1px solid rgba(255,255,255,.35);font-size:13px;opacity:.95}
    .stat-blue{background:var(--blue)} .stat-green{background:var(--green)} .stat-yellow{background:var(--yellow);color:#1f2937} .stat-red{background:var(--red)}
    .two-col{display:grid;grid-template-columns:2fr 1fr;gap:16px}
    .chart-mock{height:280px;background:linear-gradient(180deg,#f5f9ff,#e7f0ff);border:1px solid #c9dbf9;border-radius:8px;position:relative;overflow:hidden}
    .chart-wave{position:absolute;inset:auto 0 0;height:75%;background:radial-gradient(circle at 10% 80%,rgba(29,114,243,.28),transparent 40%),radial-gradient(circle at 45% 50%,rgba(20,161,87,.28),transparent 42%),radial-gradient(circle at 80% 35%,rgba(29,114,243,.24),transparent 35%)}
    .mini-panel{height:280px;border-radius:8px;background:linear-gradient(145deg,#2a81ff,#1e66d6);color:#fff;padding:14px}
    .mini-grid{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;margin-top:148px}
    .mini-box{height:55px;background:rgba(255,255,255,.18);border-radius:6px}
    table{width:100%;border-collapse:collapse;background:#fff}
    th,td{padding:11px 10px;border-bottom:1px solid #e7edf4;text-align:left;font-size:14px}
    th{background:#f8fbff;font-weight:600}
    .btn{background:#2563eb;color:#fff;border:none;border-radius:7px;padding:8px 11px;cursor:pointer}
    .btn-danger{background:#dc2626}
    .btn-secondary{background:#475569}
    .btn-success{background:#15803d}
    .btn-warning{background:#d97706}
    input,select,textarea{width:100%;padding:10px 11px;margin:6px 0 12px;border:1px solid #ccd6e2;border-radius:8px;font:inherit;background:#fff}
    textarea{resize:vertical}
    small{color:var(--muted)}
    form.inline{display:inline}
    .header-actions,.actions,.form-actions,.form-summary{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
    .header-actions{justify-content:flex-end}
    .actions{min-width:300px}
    .table-wrap{overflow-x:auto}
    .toolbar{display:grid;grid-template-columns:minmax(220px,420px) auto auto 1fr;gap:8px;align-items:center;margin-bottom:14px}
    .toolbar input{margin:0}
    .form-card{max-width:920px}
    .form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:4px 18px}
    .form-grid label{font-size:14px;font-weight:600}
    .field-full{grid-column:1 / -1}
    .check-field{display:flex;flex-direction:column}
    .check-row{min-height:43px;display:flex;align-items:center;gap:8px;font-weight:400}
    .check-row input{width:auto;margin:0}
    .form-actions{margin-top:12px;padding-top:16px;border-top:1px solid var(--line)}
    .form-summary{background:#f8fbff;border:1px solid var(--line);border-radius:8px;padding:10px 12px;margin-bottom:18px}
    .form-summary span{color:var(--muted);font-size:13px}
    nav[role="navigation"]{margin-top:14px}
    nav[role="navigation"] > div:first-child{display:none}
    nav[role="navigation"] > div:last-child{display:flex;justify-content:center}
    nav[role="navigation"] .relative.z-0{display:flex;gap:6px;flex-wrap:wrap;background:#fff;border:1px solid var(--line);padding:8px;border-radius:12px;box-shadow:var(--shadow)}
    nav[role="navigation"] span[aria-current="page"] span,
    nav[role="navigation"] a,
    nav[role="navigation"] span[aria-disabled="true"] span{
      min-width:38px;height:38px;display:inline-flex;align-items:center;justify-content:center;
      border-radius:9px;border:1px solid #d7e0eb;font-size:13px;line-height:1;padding:0 10px;text-decoration:none
    }
    nav[role="navigation"] a{color:#334155;background:#fff}
    nav[role="navigation"] a:hover{background:#eff6ff;border-color:#93c5fd;color:#1d4ed8}
    nav[role="navigation"] span[aria-current="page"] span{background:var(--blue);border-color:var(--blue);color:#fff;font-weight:600}
    nav[role="navigation"] span[aria-disabled="true"] span{background:#f8fafc;color:#94a3b8}
    nav[role="navigation"] svg{width:14px;height:14px}
    .login-shell{min-height:100vh;background:#464a74;display:grid;place-items:center;padding:20px}
    .login-card{width:min(100%,1000px);min-height:640px;background:#4b4f75;border-radius:34px;box-shadow:0 30px 40px rgba(12,14,35,.45);position:relative;overflow:hidden;padding:64px 52px;color:#eef1ff}
    .blob-a,.blob-b{position:absolute;border-radius:46% 54% 62% 38% / 52% 41% 59% 48%}
    .blob-a{width:290px;height:320px;left:-130px;top:-30px;background:rgba(57,191,203,.55)}
    .blob-b{width:340px;height:220px;left:38px;top:-45px;background:rgba(74,95,215,.65)}
    .login-inner{max-width:420px;margin:90px auto 0;position:relative;z-index:2}
    .logo-mark{font-size:44px;font-weight:700;letter-spacing:.03em}
    .logo-sub{margin-top:6px;color:#b7c1de}
    .welcome{font-size:52px;font-weight:300;margin:44px 0 30px}
    .field label{display:block;color:#d5dbf3;margin-bottom:7px}
    .line-input{background:transparent;border:none;border-bottom:2px solid #d9e1f6;border-radius:0;color:#fff;padding:8px 0}
    .line-input:focus{outline:none;border-bottom-color:#2ad1db}
    .sign-btn{margin-top:16px;width:100%;border:none;border-radius:6px;padding:13px 16px;font-size:30px;background:#2ed0db;color:#1c2744;cursor:pointer}
    .login-foot{position:absolute;left:0;right:0;bottom:30px;text-align:center;color:#c7cde6}
    .login-foot a{color:#c7cde6}
    @media (max-width:1080px){.stats-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.two-col{grid-template-columns:1fr}}
    @media (max-width:860px){.sidebar{display:none}.content{padding:14px}.topbar{padding:0 12px}.stats-grid{grid-template-columns:1fr}.content-header h1{font-size:22px}.login-card{padding:42px 24px;min-height:540px}.welcome{font-size:40px}.form-grid{grid-template-columns:1fr}.field-full{grid-column:auto}.toolbar{grid-template-columns:1fr auto}.header-actions{align-items:flex-end;flex-direction:column}.content-header{align-items:flex-start}}
  </style>
  @yield('head')
</head>
<body>
@auth
  <div class="app">
    <aside class="sidebar">
      <div class="brand">
        <div class="brand-badge">A</div>
        <strong>AdminLTE 4 Style</strong>
      </div>
      <div class="menu-title">Main</div>
      <nav class="menu">
        <a class="{{ request()->routeIs('admin.dashboard') ? 'active' : '' }}" href="{{ route('admin.dashboard') }}">Dashboard</a>
        <a class="{{ request()->routeIs('admin.users*') ? 'active' : '' }}" href="{{ route('admin.users') }}">Users</a>
        <a class="{{ request()->routeIs('admin.funding-requests*') ? 'active' : '' }}" href="{{ route('admin.funding-requests') }}">Wallet Messages</a>
        <a class="{{ request()->routeIs('admin.withdraw-requests*') ? 'active' : '' }}" href="{{ route('admin.withdraw-requests') }}">Withdraw Requests</a>
        <a class="{{ request()->routeIs('admin.matches*') ? 'active' : '' }}" href="{{ route('admin.matches') }}">Matches</a>
        <a class="{{ request()->routeIs('admin.transactions*') ? 'active' : '' }}" href="{{ route('admin.transactions') }}">Transactions</a>
      </nav>
      <div class="menu-title">System</div>
      <nav class="menu">
        <a href="#">Reports</a>
        <a href="#">Fraud Signals</a>
      </nav>
      <div class="menu-title">Dashboard Sections</div>
      <nav class="menu">
        <a href="{{ route('admin.dashboard') }}#admin-send-notification">Send Notification</a>
        <a href="{{ route('admin.dashboard') }}#admin-match-commission">Match Commission</a>
      </nav>
    </aside>
    <main class="main">
      <header class="topbar">
        <div class="topbar-title">Chess Betting Platform / Admin Control</div>
        <form method="POST" action="{{ route('admin.logout') }}">@csrf <button class="logout-btn" type="submit">Logout</button></form>
      </header>
      <section class="content">
        @if(session('success'))<div class="flash ok">{{ session('success') }}</div>@endif
        @if(session('error'))<div class="flash err">{{ session('error') }}</div>@endif
        @if($errors->any())<div class="flash err">{{ $errors->first() }}</div>@endif
        @yield('content')
      </section>
    </main>
  </div>
@else
  @yield('content')
@endauth
</body>
</html>
