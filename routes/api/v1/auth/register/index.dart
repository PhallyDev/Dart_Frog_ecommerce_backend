import 'package:dart_frog/dart_frog.dart';
import '../signup/index.dart' as signup;

Future<Response> onRequest(RequestContext context) => signup.onRequest(context);
