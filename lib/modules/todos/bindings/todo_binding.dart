import 'package:get/get.dart';
import '../controllers/todo_controller.dart';

/// Injects dependencies for the Todos module.
class TodoBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TodoController>(() => TodoController());
  }
}
