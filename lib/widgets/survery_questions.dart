import 'package:flutter/material.dart';
import 'package:flutter_cv/screens/camera_screen_tflite.dart';

class SurveyQuestions extends StatefulWidget {
  const SurveyQuestions({super.key});

  @override
  State<SurveyQuestions> createState() => _SurveyQuestionsState();
}

class _SurveyQuestionsState extends State<SurveyQuestions> {
  int _questionNumber = 1;
  // ignore: prefer_final_fields
  List<Map<String, dynamic>> _questions = [
    {
      "question": "How are you feeling today?",
      "options": [
        "I am feeling well",
        "I do not feel well",
      ],
      "selected": null,
      "correct": 0,
    },
    {
      "question": "Do you have any drug allergies",
      "options": [
        "Yes",
        "No",
      ],
      "selected": null,
      "correct": 1,
    },
    {
      "question": "Acknowledgement",
      "description":
          "Please be aware that you will be recorded, and the data collected will be used for future model training to enhance the AV-MED model. Your data will be safely protected and will only be made available to the Synapxe DNA Project Team. Please click ‘agree’ to proceed.",
      "options": [
        "Agree",
        "Disagree",
      ],
      "selected": null,
      "correct": 0,
    }
  ];

  @override
  void initState() {
    super.initState();
    print(_questions[0]['selected']);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Question $_questionNumber / ${_questions.length}"),
            Text(
              _questions[_questionNumber - 1]["question"],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (_questions[_questionNumber - 1].containsKey("description"))
              Text(_questions[_questionNumber - 1]["description"]),
            const SizedBox(
              height: 5,
            ),
            Column(
              children: [
                for (int i = 0;
                    i < _questions[_questionNumber - 1]["options"].length;
                    i++) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: _questions[_questionNumber - 1]["selected"] == i
                          ? Color.fromARGB(255, 190, 251, 193)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RadioListTile(
                      title: Text(
                        _questions[_questionNumber - 1]["options"][i],
                        style: TextStyle(color: Colors.black),
                      ),
                      value: i,
                      groupValue: _questions[_questionNumber - 1]["selected"],
                      activeColor: Colors.green,
                      selected:
                          _questions[_questionNumber - 1]["selected"] == i,
                      onChanged: (value) {
                        setState(() {
                          _questions[_questionNumber - 1]["selected"] = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                ],
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _questions[_questionNumber - 1]['selected'] ==
                        _questions[_questionNumber - 1]['correct']
                    ? () {
                        print(_questions[_questionNumber - 1]);
                        if (_questionNumber < _questions.length) {
                          setState(() {
                            _questionNumber++;
                          });
                        } else {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CameraScreenTFLite(),
                              ));
                        }
                      }
                    : null,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    _questions[_questionNumber - 1]['selected'] ==
                            _questions[_questionNumber - 1]['correct']
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  foregroundColor: MaterialStateProperty.all<Color>(
                    _questions[_questionNumber - 1]['selected'] ==
                            _questions[_questionNumber - 1]['correct']
                        ? Colors.white
                        : Colors.black,
                  ),
                  side: MaterialStateProperty.all<BorderSide>(
                    BorderSide(
                      color: Colors.black,
                      width: _questions[_questionNumber - 1]['selected'] ==
                              _questions[_questionNumber - 1]['correct']
                          ? 0
                          : 1,
                    ),
                  ),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                child: const Text("Next"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
