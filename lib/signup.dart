
import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();

  TextEditingController passwordController = TextEditingController();

  String? checkName(String? value){
    if(value == null || value.isEmpty){
      return "Enter your name";
    }

    if(value.contains("  ")){
      return "No double spaces";
    }

    if(!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)){
      return "Letters only";
    }

    return null;
  }

  String? checkEmail(String? value){
    if(value == null || value.isEmpty){
      return "Enter email";
    }

    if(!value.contains("@")){
      return "Email incorrect";
    }

    return null;
  }

  String? checkCIN(String? value){
    if(value == null || value.isEmpty){
      return "Enter CIN";
    }

    if(!RegExp(r'^[0-9]{8}$').hasMatch(value)){
      return "CIN must be 8 numbers";
    }

    return null;
  }

  String? checkPassword(String? value){
    if(value == null || value.isEmpty){
      return "Enter password";
    }

    if(value.length < 4){
      return "Minimum 4 characters";
    }

    return null;
  }

  String? checkConfirmPassword(String? value){
    if(value != passwordController.text){
      return "Passwords not match";
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(25),

            child: Form(
              key: _formKey,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  SizedBox(height: 40),

                  Center(
                    child: Text(
                      "Sign Up",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),

                  SizedBox(height: 25),

                  TextFormField(
                    validator: checkName,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),

                  SizedBox(height: 15),

                  TextFormField(
                    validator: checkEmail,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),

                  SizedBox(height: 15),

                  TextFormField(
                    validator: checkCIN,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "CIN",
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),

                  SizedBox(height: 15),

                  TextFormField(
                    controller: passwordController,
                    validator: checkPassword,
                    obscureText: hidePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock),

                      suffixIcon: IconButton(
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: (){
                          setState(() {
                            hidePassword = !hidePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 15),

                  TextFormField(
                    validator: checkConfirmPassword,
                    obscureText: hideConfirmPassword,
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      prefixIcon: Icon(Icons.lock),

                      suffixIcon: IconButton(
                        icon: Icon(
                          hideConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: (){
                          setState(() {
                            hideConfirmPassword = !hideConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 25),

                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF4facfe),
                          Color(0xFFfa71cd),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),

                    child: ElevatedButton(
                      onPressed: (){
                        if(_formKey.currentState!.validate()){
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Account created"),
                            ),
                          );
                        }
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),

                      child: Text("SIGN UP"),
                    ),
                  ),

                  SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account?"),
                      TextButton(
                        onPressed: (){
                          Navigator.pop(context);
                        },
                        child: Text("Login"),
                      )
                    ],
                  )

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
