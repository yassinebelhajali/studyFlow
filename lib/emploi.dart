import 'package:flutter/material.dart';

void main() {
  runApp(const StudyFlowApp());
}

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "StudyFlow",
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        fontFamily: 'Poppins',
      ),
      home: const SchedulePage(),
    );
  }
}

// 📚 SUBJECT MODEL
class Subject {
  final String title;
  final String room;
  final String teacher;
  final Color accentColor;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Subject({
    required this.title,
    required this.room,
    required this.teacher,
    required this.accentColor,
    required this.startTime,
    required this.endTime,
  });
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final PageController _pageController = PageController();

  int selectedDayIndex = 0;

  final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  final List<List<Subject>> weeklySchedule = [
    // MONDAY
    [
      Subject(
        title: "CR-Entrepots de Données",
        room: "A-KANOUN",
        teacher: "Mr. Nefaa Haffar",
        accentColor: Colors.blue,
        startTime: const TimeOfDay(hour: 8, minute: 30),
        endTime: const TimeOfDay(hour: 10, minute: 0),
      ),
      Subject(
        title: "TP-Programmation IA",
        room: "A-07",
        teacher: "Mrs. Azza Chebil",
        accentColor: Colors.green,
        startTime: const TimeOfDay(hour: 10, minute: 15),
        endTime: const TimeOfDay(hour: 11, minute: 45),
      ),
      Subject(
        title: "CR-Business Intelligence and Data Analytics",
        room: "A-KANOUN",
        teacher: "Mrs. Raghda Jouirou",
        accentColor: Colors.orange,
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 30),
      ),
      Subject(
        title: "TP-1/15-Tests de logiciels (certification ISTQB)",
        room: "A-31",
        teacher: "Mrs. Ichrak Mehrez",
        accentColor: const Color.fromARGB(255, 132, 0, 255),
        startTime: const TimeOfDay(hour: 14, minute: 45),
        endTime: const TimeOfDay(hour: 16, minute: 15),
      ),
      Subject(
        title: "TP-1/15-Techniques d'indexation et de recherche multimédia",
        room: "A-06",
        teacher: "Mr. Mohamed Amine Ben Charrada",
        accentColor: const Color.fromARGB(255, 255, 0, 106),
        startTime: const TimeOfDay(hour: 16, minute: 30),
        endTime: const TimeOfDay(hour: 18, minute: 0),
      ),
    ],

    // TUESDAY
    [
      Subject(
        title: "TP-1/15-Business Intelligence and Data Analytics",
        room: "A-01",
        teacher: "Mrs. Raghda Jouirou",
        accentColor: Colors.purple,
        startTime: const TimeOfDay(hour: 8, minute: 30),
        endTime: const TimeOfDay(hour: 10, minute: 0),
      ),
      Subject(
        title: "TP-1/15-Digital Business Transformation",
        room: "A-12",
        teacher: "Mrs. Eslem Romdhane",
        accentColor: Colors.indigo,
        startTime: const TimeOfDay(hour: 8, minute: 30),
        endTime: const TimeOfDay(hour: 10, minute: 0),
      ),
      Subject(
        title: "TP-Techniques de compilation",
        room: "A-02",
        teacher: "Mrs. Sameh Ghallebi",
        accentColor: Colors.red,
        startTime: const TimeOfDay(hour: 10, minute: 15),
        endTime: const TimeOfDay(hour: 11, minute: 45),
      ),
      Subject(
        title: "TP-Administration des bases de données",
        room: "A-03",
        teacher: "Mrs. Maleke Chatti",
        accentColor: const Color.fromARGB(255, 54, 244, 57),
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 30),
      ),
      Subject(
        title: "TP-Technologies et programmation web",
        room: "A-07",
        teacher: "Mrs. Senda Laataoui",
        accentColor: const Color.fromARGB(255, 54, 146, 244),
        startTime: const TimeOfDay(hour: 15, minute: 0),
        endTime: const TimeOfDay(hour: 17, minute: 0),
      ),
      Subject(
        title: "CR-Programmation IA",
        room: "A-KANOUN",
        teacher: "Mr. Nefaa Haffar",
        accentColor: const Color.fromARGB(255, 54, 146, 244),
        startTime: const TimeOfDay(hour: 16, minute: 30),
        endTime: const TimeOfDay(hour: 18, minute: 0),
      ),
    ],

    // WEDNESDAY
    [
      Subject(
        title: "TP-Technologies et programmation web",
        room: "A-06",
        teacher: "Mrs. Senda Laataoui",
        accentColor: Colors.teal,
        startTime: const TimeOfDay(hour: 8, minute: 30),
        endTime: const TimeOfDay(hour: 10, minute: 0),
      ),
      Subject(
        title: "CR-Techniques de compilation",
        room: "A-KANOUN",
        teacher: "Mrs. Aida Lahouij",
        accentColor: Colors.cyan,
        startTime: const TimeOfDay(hour: 10, minute: 15),
        endTime: const TimeOfDay(hour: 11, minute: 45),
      ),
      Subject(
        title: "TD-Anglais",
        room: "C-24",
        teacher: "Mrs. Lilia Zouari",
        accentColor: Colors.pink,
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 30),
      ),
      Subject(
        title: "CR-Techniques d'indexation et de recherche multimédia",
        room: "A-KANOUN",
        teacher: "Mrs. Imen Chabbi",
        accentColor: const Color.fromARGB(255, 47, 233, 30),
        startTime: const TimeOfDay(hour: 14, minute: 45),
        endTime: const TimeOfDay(hour: 16, minute: 15),
      ),
    ],

    // THURSDAY
    [
      Subject(
        title: "TD-1/15-Techniques de compilation",
        room: "C-23",
        teacher: "Mrs. Sameh Ghallebi",
        accentColor: Colors.deepPurple,
        startTime: const TimeOfDay(hour: 8, minute: 30),
        endTime: const TimeOfDay(hour: 10, minute: 0),
      ),
      Subject(
        title: "TP-Programmation IA",
        room: "A-05",
        teacher: "Mrs. Azza Chebil",
        accentColor: Colors.lightGreen,
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 30),
      ),
      Subject(
        title: "CR-Technologies et programmation web",
        room: "A-KANOUN",
        teacher: "Mrs. Dorra Dhaou",
        accentColor: Colors.amber,
        startTime: const TimeOfDay(hour: 14, minute: 45),
        endTime: const TimeOfDay(hour: 16, minute: 15),
      ),
      Subject(
        title: "CR-1/15-Administration des bases de données",
        room: "A-KANOUN",
        teacher: "Mrs. Sana Hamdi",
        accentColor: const Color.fromARGB(255, 7, 106, 255),
        startTime: const TimeOfDay(hour: 16, minute: 30),
        endTime: const TimeOfDay(hour: 18, minute: 0),
      ),
    ],

    // FRIDAY
    [
      Subject(
        title: "CR-Digital Business Transformation",
        room: "A-KANOUN",
        teacher: "Mr. Ahmed Wajdi Abdallah",
        accentColor: Colors.blueGrey,
        startTime: const TimeOfDay(hour: 8, minute: 30),
        endTime: const TimeOfDay(hour: 10, minute: 0),
      ),
      Subject(
        title: "CR-Droit d'informatique,protection des données et éthique",
        room: "A-KANOUN",
        teacher: "Mrs. Wejden Allali",
        accentColor: Colors.deepOrange,
        startTime: const TimeOfDay(hour: 10, minute: 15),
        endTime: const TimeOfDay(hour: 11, minute: 45),
      ),
      Subject(
        title: "CR-Tests de logiciels (certification ISTQB)",
        room: "A-KANOUN",
        teacher: "Mrs. Sarra Mejri",
        accentColor: Colors.brown,
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
      ),
    ],

    // SATURDAY
    [
      Subject(
        title: "TP-Projet fedéré (methode Agile)-(non-présentiel)",
        room: "Library",
        teacher: "Self Study",
        accentColor: Colors.grey,
        startTime: const TimeOfDay(hour: 10, minute: 15),
        endTime: const TimeOfDay(hour: 11, minute: 45),
      ),
    ],
  ];

  bool isCurrentClass(Subject subject) {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    final start = subject.startTime.hour * 60 + subject.startTime.minute;
    final end = subject.endTime.hour * 60 + subject.endTime.minute;
    return nowMin >= start && nowMin <= end;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        toolbarHeight: 90,
        title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded,),
             SizedBox(width: 10,),               
              Text(
            "Emploi du Temps",
            style: TextStyle(fontFamily:"Roboto", fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)
          ),

            ],

          ),
          SizedBox(height: 6),
          Text(
            "Your weekly schedule",
            style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
          ),
        ],
      ),
      ),
      body: Column(
        children: [

          const SizedBox(height: 10),
          _buildDaySelector(),
          const SizedBox(height: 10),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: days.length,
              onPageChanged: (index) {
                setState(() => selectedDayIndex = index);
              },
              itemBuilder: (context, index) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _buildTimeline(weeklySchedule[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDaySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(days.length, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _DayChip(
                label: days[index],
                isSelected: index == selectedDayIndex,
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimeline(List<Subject> subjects) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        final now = isCurrentClass(subject);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(
                subject.startTime.format(context),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Column(
              children: [
                Container(width: 3, height: 20, color: Colors.grey[300]),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: subject.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(width: 3, height: 110, color: Colors.grey[300]),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: now
                          ? subject.accentColor.withOpacity(0.30)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: now ? 15 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subject.room,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 18,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subject.teacher,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DayChip> createState() => _DayChipState();
}

class _DayChipState extends State<_DayChip> {
  double scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => scale = 0.9),
      onTapUp: (_) {
        setState(() => scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => scale = 1.0),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFF2563EB)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.label,
              maxLines: 1,
              style: TextStyle(
                color: widget.isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}