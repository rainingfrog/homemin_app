import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('handouts');
  runApp(FamilyInventoryApp());
}

class FamilyInventoryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Inventory',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: SplashPage(),
    );
  }
}

class SplashPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to Family Inventory',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HandOutPage()),
                );
              },
              child: Text('Hand Out', style: TextStyle(fontSize: 18)),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Inventory page coming soon!')),
                );
              },
              child: Text('Inventory', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class HandOutPage extends StatefulWidget {
  @override
  _HandOutPageState createState() => _HandOutPageState();
}

class _HandOutPageState extends State<HandOutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _adultsController = TextEditingController();
  final _kidsController = TextEditingController();
  final _searchController = TextEditingController();

  String _searchQuery = '';

  void _submitForm() {
    final familyName = _nameController.text.trim();
    final adults = int.tryParse(_adultsController.text.trim()) ?? 0;
    final kids = int.tryParse(_kidsController.text.trim()) ?? 0;

    if (familyName.isEmpty || adults < 0 || kids < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields correctly.')),
      );
      return;
    }

    final bagCounts = calculateBags(adults, kids);
    final brownBags = bagCounts['brown']!;
    final whiteBags = bagCounts['white']!;

    final box = Hive.box('handouts');
    final record = {
      'familyName': familyName,
      'adults': adults,
      'kids': kids,
      'brownBags': brownBags,
      'whiteBags': whiteBags,
      'timestamp': DateTime.now().toIso8601String(),
    };

    box.add(record);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Saved $familyName: $adults adults, $kids kids → $brownBags brown, $whiteBags white'),
    ));

    _nameController.clear();
    _adultsController.clear();
    _kidsController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('handouts');

    return Scaffold(
      appBar: AppBar(title: Text('Hand Out')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(children: [
          Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Family Name'),
              ),
              TextFormField(
                controller: _adultsController,
                decoration: InputDecoration(labelText: 'Number of Adults'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _kidsController,
                decoration: InputDecoration(labelText: 'Number of Kids'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text('Save'),
              ),
            ]),
          ),
          SizedBox(height: 20),
          Divider(),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Saved Handouts',
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  setState(() {
                    _searchQuery = _searchController.text.trim().toLowerCase();
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box box, _) {
                final items = box.values.toList().asMap().entries.where((entry) {
                  final record = entry.value as Map;
                  final name = record['familyName'].toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (items.isEmpty) {
                  return Center(child: Text('No matching families found.'));
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final index = items[i].key;
                    final record = items[i].value;
                    final name = record['familyName'];
                    final adults = record['adults'];
                    final kids = record['kids'];
                    final brown = record['brownBags'];
                    final white = record['whiteBags'];

                    return ListTile(
                      title: Text(name),
                      subtitle: Text('$adults adults, $kids kids → $brown brown, $white white'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Delete "$name"?'),
                                content: Text('Are you sure you want to permanently delete this family?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      box.deleteAt(index);
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Deleted $name')),
                                      );
                                    },
                                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

Map<String, int> calculateBags(int adults, int kids) {
  int brown = 1;
  int white = 1;

  if (adults >= 4 && kids == 0) {
    brown = 2;
    white = 1;
  } else if (adults == 2 && kids >= 4) {
    brown = 1;
    white = 2;
  } else if (adults == 2 && kids <= 3) {
    brown = 1;
    white = 1;
  } else if (adults >= 4 && kids >= 4) {
    brown = 2;
    white = 3;
  } else if (adults >= 4 && kids >= 1 && kids <= 3) {
    brown = 2;
    white = 2;
  } else if (adults >= 1 && adults <= 3 && kids == 0) {
    brown = 1;
    white = 1;
  }

  return {
    'brown': brown,
    'white': white,
  };
}
