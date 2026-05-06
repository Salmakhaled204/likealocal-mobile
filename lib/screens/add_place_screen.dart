import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _localTipController = TextEditingController();
  final _recommendedDishController = TextEditingController();

  final List<String> _categories = [
    'Restaurants', 'Hidden Gems', 'Experiences', 'Cafes', 'Nightlife', 'Other',
  ];

  String _category = 'Restaurants';
  bool _isSaving = false;
  bool _isDetectingLocation = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _localTipController.dispose();
    _recommendedDishController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() { _isDetectingLocation = true; _error = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() => _error = 'Please enable GPS.'); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) { setState(() => _error = 'Permission denied.'); return; }
      }
      if (permission == LocationPermission.deniedForever) { setState(() => _error = 'Permission permanently denied.'); return; }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      setState(() => _error = 'Could not get location. Enter manually.');
    } finally {
      setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _savePlace() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _error = 'You must be logged in.'); return; }
    setState(() { _isSaving = true; _error = null; });
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final isSuperUser = userDoc.data()?['isSuperUser'] == true;
      final imageUrl = _imageUrlController.text.trim();
      await FirebaseFirestore.instance.collection('places').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'imageUrls': imageUrl.isEmpty ? <String>[] : <String>[imageUrl],
        'localTip': _localTipController.text.trim(),
        'recommendedDish': _recommendedDishController.text.trim(),
        'location': GeoPoint(double.parse(_latitudeController.text.trim()), double.parse(_longitudeController.text.trim())),
        'ownerId': user.uid,
        'ownerIsSuperUser': isSuperUser,
        'averageRating': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'contributionCount': FieldValue.increment(1)});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place added successfully! 🎉')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to add place. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _coordinateValidator(String? value, String label, double min, double max) {
    final err = _required(value, label);
    if (err != null) return err;
    final number = double.tryParse(value!.trim());
    if (number == null) return '$label must be a number';
    if (number < min || number > max) return '$label must be between $min and $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Add Place', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(controller: _titleController, textCapitalization: TextCapitalization.words,
                validator: (v) => _required(v, 'Title'),
                decoration: const InputDecoration(labelText: 'Place title *', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (value) { if (value != null) setState(() => _category = value); }),
              const SizedBox(height: 14),
              TextFormField(controller: _descriptionController, validator: (v) => _required(v, 'Description'),
                minLines: 3, maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              TextFormField(controller: _localTipController,
                decoration: const InputDecoration(labelText: 'Local Tip (optional)', border: OutlineInputBorder(), hintText: 'e.g. Go in the morning to avoid crowds')),
              const SizedBox(height: 14),
              TextFormField(controller: _recommendedDishController,
                decoration: const InputDecoration(labelText: 'Recommended Dish (optional)', border: OutlineInputBorder(), hintText: 'e.g. Try the koshary here!')),
              const SizedBox(height: 14),
              TextFormField(controller: _imageUrlController, keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Image URL (optional)', border: OutlineInputBorder(), hintText: 'https://example.com/image.jpg')),
              const SizedBox(height: 20),
              const Text('Location *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              _isDetectingLocation
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _detectLocation,
                        icon: const Icon(Icons.my_location),
                        label: Text(_latitudeController.text.isEmpty ? 'Detect My Location' : 'Re-detect Location'))),
              const SizedBox(height: 10),
              if (_latitudeController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                  child: Row(children: [
                    const Icon(Icons.location_on, color: Colors.green), const SizedBox(width: 8),
                    Text('Lat: ${_latitudeController.text}\nLng: ${_longitudeController.text}', style: const TextStyle(fontSize: 13)),
                  ])),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (v) => _coordinateValidator(v, 'Latitude', -90, 90),
                  decoration: const InputDecoration(labelText: 'Latitude *', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (v) => _coordinateValidator(v, 'Longitude', -180, 180),
                  decoration: const InputDecoration(labelText: 'Longitude *', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: Colors.red[700]))),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _savePlace,
                  icon: _isSaving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_location_alt),
                  label: Text(_isSaving ? 'Saving...' : 'Add Place'))),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
