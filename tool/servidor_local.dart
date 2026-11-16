// Servidor local do Projeto Timetable.
//
// Serve a versão compilada (pasta "web") em http://localhost e abre o
// navegador. É o "Abrir sistema.exe" da mídia de entrega:
//
//   dart compile exe tool/servidor_local.dart -o "Abrir sistema.exe"
//
// Uso: coloque o .exe ao lado da pasta "web" (gerada por
// `flutter build web --release --no-web-resources-cdn`) e dê dois
// cliques. Também aceita a pasta como argumento:
//   "Abrir sistema.exe" C:\caminho\para\web
//
// O sistema precisa de internet para acessar o banco (Supabase).

import 'dart:io';

const _tipos = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream',
  '.frag': 'application/octet-stream',
};

Future<void> main(List<String> argumentos) async {
  // --sem-navegador: só liga o servidor (usado para testar).
  final abrirNavegador = !argumentos.contains('--sem-navegador');
  final args = argumentos.where((a) => !a.startsWith('--')).toList();
  final pasta = _acharPastaWeb(args);
  if (pasta == null) {
    stderr.writeln('Não encontrei a pasta "web" com o sistema compilado.');
    stderr.writeln('Coloque este programa ao lado da pasta "web".');
    _esperarEnter();
    exit(1);
  }

  final servidor = await _abrirPorta();
  final endereco = 'http://localhost:${servidor.port}/';

  stdout.writeln('Projeto Timetable');
  stdout.writeln('Sistema aberto em: $endereco');
  stdout.writeln('Deixe esta janela aberta enquanto usa o sistema.');
  stdout.writeln('Para encerrar, feche esta janela.');

  if (abrirNavegador) await _abrirNavegador(endereco);

  await for (final pedido in servidor) {
    await _responder(pedido, pasta);
  }
}

/// Pasta "web": a do argumento, ou a que está ao lado do programa.
Directory? _acharPastaWeb(List<String> args) {
  final candidatos = [
    if (args.isNotEmpty) args.first,
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}web',
    '${Directory.current.path}${Platform.pathSeparator}web',
  ];
  for (final caminho in candidatos) {
    final pasta = Directory(caminho);
    if (File('${pasta.path}${Platform.pathSeparator}index.html').existsSync()) {
      return pasta;
    }
  }
  return null;
}

/// Tenta a porta 8080; se estiver ocupada, usa outra livre.
Future<HttpServer> _abrirPorta() async {
  for (final porta in [8080, 8081, 8082, 8090]) {
    try {
      return await HttpServer.bind(InternetAddress.loopbackIPv4, porta);
    } on SocketException {
      continue;
    }
  }
  return HttpServer.bind(InternetAddress.loopbackIPv4, 0);
}

Future<void> _abrirNavegador(String endereco) async {
  try {
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', endereco]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [endereco]);
    } else {
      await Process.start('xdg-open', [endereco]);
    }
  } catch (_) {
    stdout.writeln('Abra o navegador e acesse $endereco');
  }
}

Future<void> _responder(HttpRequest pedido, Directory pasta) async {
  final resposta = pedido.response;
  try {
    var caminho = Uri.decodeComponent(pedido.uri.path);
    if (caminho.isEmpty || caminho == '/') caminho = '/index.html';
    // Não deixa sair da pasta "web".
    final relativo = caminho
        .split('/')
        .where((parte) => parte.isNotEmpty && parte != '..' && parte != '.')
        .join(Platform.pathSeparator);
    var arquivo = File('${pasta.path}${Platform.pathSeparator}$relativo');
    if (!arquivo.existsSync()) {
      // Rotas do app voltam para a página principal.
      arquivo = File('${pasta.path}${Platform.pathSeparator}index.html');
    }
    final nome = arquivo.path.toLowerCase();
    final ponto = nome.lastIndexOf('.');
    final extensao = ponto < 0 ? '' : nome.substring(ponto);
    resposta.headers.contentType = ContentType.parse(
      _tipos[extensao] ?? 'application/octet-stream',
    );
    if (extensao == '.html' || nome.endsWith('flutter_service_worker.js')) {
      resposta.headers.set('Cache-Control', 'no-cache');
    }
    await resposta.addStream(arquivo.openRead());
  } catch (_) {
    resposta.statusCode = HttpStatus.internalServerError;
  } finally {
    await resposta.close();
  }
}

void _esperarEnter() {
  stdout.writeln('Aperte Enter para fechar.');
  try {
    stdin.readLineSync();
  } catch (_) {}
}
