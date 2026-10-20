import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'القرآن الكريم',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const SurahListScreen(),
    );
  }
}

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<dynamic> _surahs = [];
  List<dynamic> _reciters = []; // قائمة القراء

  bool _isLoadingSurahs = true;
  bool _isLoadingReciters = true;
  bool _isPlaying = false;

  int? _currentSurahNumber;
  String _currentSurahName = '';

  int _selectedReciterId = 7; // القارئ الافتراضي (مشاري العفاسي)
  String _selectedReciterName = 'مشاري العفاسي';

  @override
  void initState() {
    super.initState();
    _fetchSurahs();
    _fetchReciters();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // 1. جلب قائمة السور
  Future<void> _fetchSurahs() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.quran.com/api/v4/chapters?language=ar'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _surahs = data['chapters'];
          _isLoadingSurahs = false;
        });
      }
    } catch (e) {
      debugPrint('خطأ في جلب السور: $e');
      setState(() => _isLoadingSurahs = false);
    }
  }

  // 2. جلب قائمة القراء المتاحين باللغة العربية
  Future<void> _fetchReciters() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.quran.com/api/v4/resources/recitations?language=ar',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _reciters = data['recitations'];
          _isLoadingReciters = false;
        });
      }
    } catch (e) {
      debugPrint('خطأ في جلب القراء: $e');
      setState(() => _isLoadingReciters = false);
    }
  }

  // 3. تشغيل أو استئناف سورة
  Future<void> _playSurahAudio(int surahNumber, String surahName) async {
    if (_currentSurahNumber == surahNumber) {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
      return;
    }

    setState(() {
      _currentSurahNumber = surahNumber;
      _currentSurahName = surahName;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.quran.com/api/v4/chapter_recitations/$_selectedReciterId/$surahNumber',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String audioUrl = data['audio_file']['audio_url'];

        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
      }
    } catch (e) {
      debugPrint('خطأ في تشغيل الصوت: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
         
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage("images/back.jpeg"),fit: BoxFit.cover),
        ),
        child: Column(
          children: [
            // قائمة اختيار القارئ في أعلى الشاشة
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.teal.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'اختر القارئ:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  _isLoadingReciters
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : DropdownButton<int>(
                          value: _selectedReciterId,
                          items: _reciters.map<DropdownMenuItem<int>>((
                            reciter,
                          ) {
                            return DropdownMenuItem<int>(
                              value: reciter['id'],
                              child: Text(
                                reciter['translated_name']['name'] ??
                                    reciter['reciter_name'],
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (int? newReciterId) {
                            if (newReciterId != null) {
                              final selected = _reciters.firstWhere(
                                (r) => r['id'] == newReciterId,
                              );
                              setState(() {
                                _selectedReciterId = newReciterId;
                                _selectedReciterName =
                                    selected['translated_name']['name'] ??
                                    selected['reciter_name'];
                              });

                              // إعادة تشغيل السورة الحالية بالقارئ الجديد إذا كانت تعمل
                              if (_currentSurahNumber != null) {
                                _playSurahAudio(
                                  _currentSurahNumber!,
                                  _currentSurahName,
                                );
                              }
                            }
                          },
                        ),
                ],
              ),
            ),

            // قائمة السور
            Expanded(
              child: _isLoadingSurahs
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _surahs.length,
                      itemBuilder: (context, index) {
                        final surah = _surahs[index];
                        final int surahNumber = surah['id'];
                        final String surahName = surah['name_arabic'];
                        final bool isSelected =
                            _currentSurahNumber == surahNumber;

                        return ListTile(
                          leading: CircleAvatar(child: Text('$surahNumber')),
                          title: Text(surahName,style: TextStyle(color: Colors.white,fontSize: 30,fontWeight: FontWeight.bold),),
                          // عند الضغط على اسم السورة يتم فتح القراءة النصية للمصحف
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SurahDetailScreen(
                                  surahNumber: surahNumber,
                                  surahName: surahName,
                                ),
                              ),
                            );
                          },
                          // زر التشغيل الصوتي يبقي كما هو في الـ trailing
                          trailing: IconButton(
                            icon: Icon(
                              isSelected && _isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              color: isSelected ? Colors.teal : Colors.grey,
                              size: 36,
                            ),
                            onPressed: () =>
                                _playSurahAudio(surahNumber, surahName),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // مشغل صوتيات سفلي
      bottomNavigationBar: _currentSurahNumber != null
          ? Container(
              color: Colors.teal.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سورة $_currentSurahName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'القارئ: $_selectedReciterName',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle : Icons.play_circle,
                      size: 36,
                      color: Colors.teal.shade900,
                    ),
                    onPressed: () {
                      if (_isPlaying) {
                        _audioPlayer.pause();
                      } else {
                        _audioPlayer.resume();
                      }
                    },
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class SurahDetailScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;

  const SurahDetailScreen({
    super.key,
    required this.surahNumber,
    required this.surahName,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  List<dynamic> _verses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSurahVerses();
  }

  // جلب نص الآيات للسورة المحددة
  Future<void> _fetchSurahVerses() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.quran.com/api/v4/quran/verses/uthmani?chapter_number=${widget.surahNumber}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _verses = data['verses'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('خطأ في جلب الآيات: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سورة ${widget.surahName}'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // البسملة لغير سورة التوبة (سورة رقم 9)
                if (widget.surahNumber != 9 && widget.surahNumber != 1)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ),

                // عرض الآيات متصلة أو كقائمة
                RichText(
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                  text: TextSpan(
                    children: _verses.map((verse) {
                      return TextSpan(
                        text: '${verse['text_uthmani']} ﴿${verse['id']}﴾ ',
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.black,
                          height: 2.0,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}
