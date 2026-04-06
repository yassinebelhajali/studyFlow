import 'package:flutter/material.dart';

class CoursPage extends StatefulWidget {
  Container block(int nbc, MaterialColor c, String m, String k, String d, String v) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: c[100]!,
          blurRadius:4,
          offset: Offset(0, 6),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 25,
            width: 80,
            decoration: BoxDecoration(
              color: c[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '$nbc Credits',
                style: TextStyle(fontWeight: FontWeight.bold, color: c[900]),
              ),
            ),
          ),
          SizedBox(height: 10),
          Text(m, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 15),
          Row(
            children: [
              Icon(Icons.person_2_outlined, size: 20),
              SizedBox(width: 6),
              Text(k, style: TextStyle(fontSize: 13)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 20),
              SizedBox(width: 6),
              Text(d, style: TextStyle(fontSize: 13)),
            ],
          ),
          SizedBox(height: 10),
          Divider(color: Colors.grey[200]),
          SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Room A$v", style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: c[200],
                  padding: EdgeInsets.symmetric(horizontal: 33, vertical: 8),
                ),
                child: Text("Open", style: TextStyle(color: c[900])),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  State<CoursPage> createState() => _CoursPageState();
}

class _CoursPageState extends State<CoursPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        toolbarHeight: 90,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 28, color: Colors.blue),
                SizedBox(width: 10),
                Text('My Courses', style: TextStyle(fontFamily:"Roboto", fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white))
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.menu_book_outlined, color: Colors.white, size: 15),
                SizedBox(width: 9),
                Text("10 courses", style: TextStyle(fontSize: 15, color: Colors.white)),
                SizedBox(width: 13),
                Icon(Icons.school, size: 16, color: Colors.white),
                SizedBox(width: 9),
                Text("26 credits", style: TextStyle(fontSize: 15, color: Colors.white)),
              ],
            )
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              widget.block(2,Colors.blue,"Entrepôts de données","Mr.Nafaa Haffar","Mon,Wed 17:00-19:30","01"),
              widget.block(3,Colors.green,"Business Intelligence and Data Analytics","Mr.Ragheb Jourou","Tue 19:00-20:30","02"),
              widget.block(4,Colors.lightGreen,"programmation IA","Ms.Nadia Haji Aissaoui","Mon,Tue 20:45-22:00","03"),
              widget.block(3,Colors.teal, "Techniques de compilation","Ms.Malek Ltaief","Sat,Sun 08:00-10:00","04"),
              widget.block(3, Colors.deepPurple, "Technologies et programmation web","Mr.Sami Laajlaoui","Sat,Sun 10:30-13:00","05"),
              widget.block(2, Colors.orange, "Administration des bases de données","Ms.Malek Chiatti","Mon,Wed 10:00-12:0","06"),
              widget.block(3,Colors.blueGrey, "Digital Business Transformation","Mr.Ahmed Wajdi Abdallah","Fri 16:00-18:00","07"),
              widget.block(2,Colors.lightGreen,"IT Law, Data Protection and Ethics","Ms.Wijden Allali","Sat,Sat 15:00-17:00","08"),
              widget.block(2,Colors.brown,"Software Testing (ISTQB Certification)","Ms.Imen Mejri","Sat,Sat 18:00-20:00","09"),
              widget.block(2,Colors.lightBlue,"English","Mr.Lina Zouari","Mon,Wed 17:00-19:30","10"),
            ],
          ),
        ),
      ),
    );
  }
}