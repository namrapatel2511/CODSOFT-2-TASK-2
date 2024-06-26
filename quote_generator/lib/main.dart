import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:video_player/video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Random Quote App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: QuotePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Quote {
  final String text;
  final String author;

  Quote(this.text, this.author);

  Map<String, dynamic> toJson() => {
        'text': text,
        'author': author,
      };

  static Quote fromJson(Map<String, dynamic> json) {
    return Quote(
      json['text'],
      json['author'],
    );
  }
}

class QuotePage extends StatefulWidget {
  const QuotePage({super.key});

  @override
  _QuotePageState createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage> {
  String quote = 'Loading...';
  List<Quote> savedQuotes = [];
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    fetchQuote();
    loadSavedQuotes();
    _controller = VideoPlayerController.asset('assets/background.mp4')
      ..initialize().then((_) {
        setState(() {
          _controller.setLooping(true);
          _controller.play();
          _isVideoInitialized = true;
        });
      }).catchError((error) {
        print("Error initializing video player: $error");
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchQuote() async {
    final response = await http.get(Uri.parse('https://type.fit/api/quotes'));
    if (response.statusCode == 200) {
      List quotes = json.decode(response.body);
      var randomQuote = quotes[Random().nextInt(quotes.length)];
      setState(() {
        quote = randomQuote['text'];
      });
    } else {
      setState(() {
        quote = 'Failed to load quote';
      });
    }
  }

  Future<void> saveQuote() async {
    setState(() {
      savedQuotes.add(Quote(quote, 'Unknown'));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quote saved!'),
        duration: Duration(seconds: 2),
      ),
    );
    await saveQuotesToPreferences();
  }

  Future<void> saveQuotesToPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> quotesJson =
        savedQuotes.map((quote) => jsonEncode(quote.toJson())).toList();
    await prefs.setStringList('savedQuotes', quotesJson);
  }

  Future<void> loadSavedQuotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? quotesJson = prefs.getStringList('savedQuotes');
    if (quotesJson != null) {
      setState(() {
        savedQuotes = quotesJson
            .map((quote) => Quote.fromJson(jsonDecode(quote)))
            .toList();
      });
    }
  }

  void showShareOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white),
              title: const Text('Copy to clipboard',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: quote));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Other options',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                Share.share(
                  quote,
                  subject: 'Quote from Random Quote App',
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Random Quote App'),
        backgroundColor: Colors.black,
      ),
      body: _isVideoInitialized
          ? Stack(
              children: [
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size?.width ?? 0,
                      height: _controller.value.size?.height ?? 0,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.black.withOpacity(0.2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '"$quote"',
                        style: GoogleFonts.roboto(
                          textStyle: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: fetchQuote,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                            ),
                            icon: const Icon(Icons.refresh, size: 28),
                            label: Text('New Quote',
                                style: GoogleFonts.roboto(fontSize: 18)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: saveQuote,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                            ),
                            icon: const Icon(Icons.favorite,
                                color: Colors.red, size: 28),
                            label: Text('Save',
                                style: GoogleFonts.roboto(fontSize: 18)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(child: CircularProgressIndicator()),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.format_quote, color: Colors.white),
            label: 'Current Quote',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.save, color: Colors.white),
            label: 'Saved Quotes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share, color: Colors.white),
            label: 'Share Quote',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            fetchQuote();
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavedQuotesPage(savedQuotes, removeQuote),
              ),
            );
          } else if (index == 2) {
            showShareOptions();
          }
        },
      ),
    );
  }

  void removeQuote(int index) async {
    setState(() {
      savedQuotes.removeAt(index);
    });
    await saveQuotesToPreferences();
  }
}

class SavedQuotesPage extends StatelessWidget {
  final List<Quote> savedQuotes;
  final Function(int) removeQuote;

  SavedQuotesPage(this.savedQuotes, this.removeQuote);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Quotes', style: GoogleFonts.roboto()),
        backgroundColor: Colors.black,
      ),
      body: savedQuotes.isEmpty
          ? Center(
              child: Text(
                'No saved quotes yet!',
                style: GoogleFonts.roboto(fontSize: 18, color: Colors.white),
              ),
            )
          : ListView.builder(
              itemCount: savedQuotes.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    savedQuotes[index].text,
                    style: GoogleFonts.roboto(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      removeQuote(index);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
    );
  }
}
