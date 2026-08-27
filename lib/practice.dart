import 'dart:io';
void main(){
 print("Welcome to Dart!");

 stdout.write('Enter your name ?');

 var name = stdin.readLineSync();

 print('Welcome, $name ');
}