import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import '../models/user_role.dart';

class AddPlaceScreen extends StatefulWidget {
  final Place? placeToEdit;

  const AddPlaceScreen({super.key, this.placeToEdit});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _VideoPickedTile extends StatelessWidget {
  final String label;
  final VoidCallback? onRemove;

  const _VideoPickedTile({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _localTipController = TextEditingController();
  final _recommendedDishController = TextEditingController();
  final _bestTimeController = TextEditingController();
  final _openingHoursController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String _category = 'Restaurants';
  String _budget = 'Medium';
  String _atmosphere = 'Friends';

  final List<String> _categories = [
    'Restaurants', 'Hidden Gems', 'Experiences', 'Cafes',
    'Nightlife', 'Museum', 'Shopping', 'Other',
  ];
  final List<String> _budgets = ['Cheap', 'Medium', 'Expensive'];
  final List<String> _atmospheres = ['Quiet', 'Fun', 'Family', 'Friends', 'Romantic'];

  List<XFile> _selectedImages = [];
  List<XFile> _selectedVideos = [];
  List<String> _existingImageUrls = [];
  List<String> _existingVideoUrls = [];
  final ImagePicker _picker = ImagePicker();

  LatLng? _pickedLocation;
  bool _isDetectingLocation = false;
  bool _isSaving = false;
  String? _error;
  int _uploadedCount = 0;

  bool get _isEditing => widget.placeToEdit != null;

  @override
  void initState() {
    super.initState();
    final place = widget.placeToEdit;
    if (place == null) return;

    _titleController.text = place.title;
    _descriptionController.text = place.description;
    _localTipController.text = place.localTip;
    _recommendedDishController.text = place.recommendedDish;
    _bestTimeController.text = place.bestTime;
    _openingHoursController.text = place.openingHours;
    _addressController.text = place.address;
    _category = place.category.isEmpty ? _category : place.category;
    _budget = place.budget.isEmpty ? _budget : place.budget;
    _atmosphere = place.atmosphere.isEmpty ? _atmosphere : place.atmosphere;
    _pickedLocation = LatLng(place.location.latitude, place.location.longitude);
    _latitudeController.text = place.location.latitude.toStringAsFixed(6);
    _longitudeController.text = place.location.longitude.toStringAsFixed(6);
    _existingImageUrls = List<String>.from(place.imageUrls);
    _existingVideoUrls = List<String>.from(place.videoUrls);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _localTipController.dispose();
    _recommendedDishController.dispose();
    _bestTimeController.dispose();
    _openingHoursController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final role = uid == null ? UserRole.regularFree() : await fetchUserRole(uid);
      final maxUploads = role.maxUploadsPerPlace;
      final existingCount = _existingImageUrls.length + _selectedImages.length;
      if (existingCount >= maxUploads) {
        setState(() => _error = 'Your ${role.subscriptionLabel} account can upload $maxUploads images per place.');
        return;
      }
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 70);
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = [..._selectedImages, ...images].take(maxUploads - _existingImageUrls.length).toList();
        });
      }
    } catch (e) {
      setState(() => _error = 'Could not pick images.');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final hasVideo = _existingVideoUrls.isNotEmpty || _selectedVideos.isNotEmpty;
      if (hasVideo) { setState(() => _error = 'You can attach one video per place.'); return; }
      final video = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
      if (video != null) setState(() { _selectedVideos = [video]; _error = null; });
    } catch (_) {
      setState(() => _error = 'Could not pick video.');
    }
  }

  Future<void> _detectLocation() async {
    setState(() { _isDetectingLocation = true; _error = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() => _error = 'Please enable GPS on your device.'); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) { setState(() => _error = 'Location permission denied.'); return; }
      }
      if (permission == LocationPermission.deniedForever) { setState(() => _error = 'Location permanently denied. Enable in settings.'); return; }
      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() {
        _pickedLocation = LatLng(position.latitude, position.longitude);
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      setState(() => _error = 'Could not get location. Try selecting on map.');
    } finally {
      setState(() => _isDetectingLocation = false);
    }
  }

  void _openMapPicker() {
    final defaultCenter = _pickedLocation ?? LatLng(30.0444, 31.2357);
    LatLng? tempPick = _pickedLocation;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tap to select location'),
          content: SizedBox(
            width: double.maxFinite, height: 350,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: defaultCenter, initialZoom: 13,
                onTap: (tapPos, point) => setDialogState(() => tempPick = point),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.likealocal_mobile'),
                if (tempPick != null) MarkerLayer(markers: [Marker(point: tempPick!, width: 40, height: 40, child: const Icon(Icons.location_pin, color: Colors.red, size: 36))]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: tempPick == null ? null : () {
                setState(() {
                  _pickedLocation = tempPick;
                  _latitudeController.text = tempPick!.latitude.toStringAsFixed(6);
                  _longitudeController.text = tempPick!.longitude.toStringAsFixed(6);
                });
                Navigator.pop(context);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _uploadImages(String placeId) async {
    final List<String> urls = [];
    setState(() => _uploadedCount = 0);
    for (int i = 0; i < _selectedImages.length; i++) {
      final file = File(_selectedImages[i].path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final ref = FirebaseStorage.instance.ref().child('places/$placeId/$fileName');
      final uploadTask = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await uploadTask.ref.getDownloadURL());
      setState(() => _uploadedCount = i + 1);
    }
    return urls;
  }

  Future<List<String>> _uploadVideos(String placeId) async {
    final List<String> urls = [];
    for (int i = 0; i < _selectedVideos.length; i++) {
      final file = File(_selectedVideos[i].path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
      final ref = FirebaseStorage.instance.ref().child('places/$placeId/videos/$fileName');
      final uploadTask = await ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));
      urls.add(await uploadTask.ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _savePlace() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedLocation == null) { setState(() => _error = 'Please select the place location.'); return; }
    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) { setState(() => _error = 'Please upload at least one image.'); return; }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _error = 'You must be logged in.'); return; }

    setState(() { _isSaving = true; _error = null; _uploadedCount = 0; });

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final role = UserRole.fromData(userDoc.data());
      if (!role.canAddPlaces) { if (mounted) setState(() => _error = 'Only Contributors, Super Users, and Admins can add or edit places.'); return; }
      if (_isEditing && !role.canManagePlace(widget.placeToEdit!.ownerId, user.uid)) { if (mounted) setState(() => _error = 'You can only edit places you own.'); return; }

      final isSuperUser = _isEditing ? widget.placeToEdit!.ownerIsSuperUser : role.isSuperUser;
      final userName = userDoc.data()?['displayName'] ?? 'Anonymous';

      final docRef = _isEditing
          ? FirebaseFirestore.instance.collection('places').doc(widget.placeToEdit!.id)
          : FirebaseFirestore.instance.collection('places').doc();

      final placeData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'budget': _budget,
        'atmosphere': _atmosphere,
        'localTip': _localTipController.text.trim(),
        'recommendedDish': _recommendedDishController.text.trim(),
        'bestTime': _bestTimeController.text.trim(),
        'openingHours': _openingHoursController.text.trim(),
        'address': _addressController.text.trim(),
        'imageUrls': _existingImageUrls,
        'videoUrls': _existingVideoUrls,
        'viewCount': _isEditing ? (widget.placeToEdit?.viewCount ?? 0) : 0,
        'location': GeoPoint(_pickedLocation!.latitude, _pickedLocation!.longitude),
        'createdBy': _isEditing ? widget.placeToEdit!.ownerId : user.uid,
        'createdByName': _isEditing ? widget.placeToEdit!.ownerName : userName,
        'ownerId': _isEditing ? widget.placeToEdit!.ownerId : user.uid,
        'ownerIsSuperUser': isSuperUser,
        'averageRating': _isEditing ? widget.placeToEdit!.averageRating : 0.0,
        'reviewCount': _isEditing ? widget.placeToEdit!.reviewCount : 0,
        if (!_isEditing) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) { await docRef.update(placeData); } else { await docRef.set(placeData); }

      // Upload media — fallback to placeholder if Storage not activated
      List<String> imageUrls = [];
      List<String> videoUrls = [];
      try {
        imageUrls = await _uploadImages(docRef.id);
        videoUrls = await _uploadVideos(docRef.id);
      } catch (e) {
        if (_existingImageUrls.isEmpty) {
          imageUrls = ['https://placehold.co/800x400/F5F3F0/A5A5BB?text=LikeALocal'];
        }
      }

      await docRef.update({
        'imageUrls': [..._existingImageUrls, ...imageUrls],
        'videoUrls': [..._existingVideoUrls, ...videoUrls],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place added successfully! 🎉')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to add place: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Please enter the $label.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(_isEditing ? 'Edit Place' : 'Add Place', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(controller: _titleController, textCapitalization: TextCapitalization.words, validator: (v) => _required(v, 'place name'), decoration: const InputDecoration(labelText: 'Place Name *', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()), items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) setState(() => _category = v); }, validator: (v) => v == null ? 'Please choose a category.' : null),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(initialValue: _budget, decoration: const InputDecoration(labelText: 'Budget *', border: OutlineInputBorder()), items: _budgets.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(), onChanged: (v) { if (v != null) setState(() => _budget = v); }, validator: (v) => v == null ? 'Please choose a budget.' : null),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(initialValue: _atmosphere, decoration: const InputDecoration(labelText: 'Atmosphere *', border: OutlineInputBorder()), items: _atmospheres.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(), onChanged: (v) { if (v != null) setState(() => _atmosphere = v); }, validator: (v) => v == null ? 'Please choose an atmosphere.' : null),
              const SizedBox(height: 14),
              TextFormField(controller: _descriptionController, validator: (v) => _required(v, 'description'), minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              TextFormField(controller: _addressController, validator: (v) => _required(v, 'address'), decoration: const InputDecoration(labelText: 'Address *', border: OutlineInputBorder(), hintText: 'e.g. Zamalek, Cairo, Egypt')),
              const SizedBox(height: 14),
              TextFormField(controller: _localTipController, decoration: const InputDecoration(labelText: 'Local Tip (optional)', border: OutlineInputBorder(), hintText: 'e.g. Go before sunset')),
              const SizedBox(height: 14),
              TextFormField(controller: _recommendedDishController, decoration: const InputDecoration(labelText: 'Recommended Dish / Activity (optional)', border: OutlineInputBorder(), hintText: 'e.g. Try their koshary!')),
              const SizedBox(height: 14),

              // ── 🌙 Best Time to Visit ──────────────────────────────────
              TextFormField(
                controller: _bestTimeController,
                decoration: const InputDecoration(
                  labelText: '🌙 Best Time to Visit (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Weekdays 9am–12pm, avoid Friday rush',
                  prefixIcon: Icon(Icons.access_time_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // ── 🗓️ Opening Hours ──────────────────────────────────────
              TextFormField(
                controller: _openingHoursController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '🗓️ Opening Hours (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Mon–Fri: 9am–10pm\nSat–Sun: 10am–11pm',
                  prefixIcon: Icon(Icons.schedule_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

              // ── Video ─────────────────────────────────────────────────
              const Text('Video (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              if (_existingVideoUrls.isNotEmpty)
                _VideoPickedTile(label: 'Uploaded video', onRemove: _isSaving ? null : () => setState(() => _existingVideoUrls.clear())),
              if (_selectedVideos.isNotEmpty)
                _VideoPickedTile(label: _selectedVideos.first.name, onRemove: _isSaving ? null : () => setState(() => _selectedVideos.clear())),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickVideo,
                icon: const Icon(Icons.video_library_outlined),
                label: Text(_selectedVideos.isEmpty && _existingVideoUrls.isEmpty ? 'Pick Video from Gallery' : 'Video selected'),
              ),
              const SizedBox(height: 20),

              // ── Images ────────────────────────────────────────────────
              const Text('Photos (at least 1 required)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              if (_existingImageUrls.isNotEmpty)
                SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _existingImageUrls.length, itemBuilder: (context, i) => Stack(children: [
                  Container(margin: const EdgeInsets.only(right: 8), width: 90, height: 90, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: NetworkImage(_existingImageUrls[i]), fit: BoxFit.cover))),
                  Positioned(top: 2, right: 10, child: GestureDetector(onTap: _isSaving ? null : () => setState(() => _existingImageUrls.removeAt(i)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)))),
                ]))),
              if (_existingImageUrls.isNotEmpty) const SizedBox(height: 8),
              if (_selectedImages.isNotEmpty)
                SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _selectedImages.length, itemBuilder: (context, i) => Stack(children: [
                  Container(margin: const EdgeInsets.only(right: 8), width: 90, height: 90, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: FileImage(File(_selectedImages[i].path)), fit: BoxFit.cover))),
                  Positioned(top: 2, right: 10, child: GestureDetector(onTap: _isSaving ? null : () => setState(() => _selectedImages.removeAt(i)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)))),
                ]))),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _isSaving ? null : _pickImages, icon: const Icon(Icons.photo_library), label: Text('Pick Images from Gallery (${_selectedImages.length} selected)')),
              const SizedBox(height: 20),

              // ── Location ──────────────────────────────────────────────
              const Text('Location *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              if (_pickedLocation != null)
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)), child: Row(children: [const Icon(Icons.location_on, color: Colors.green), const SizedBox(width: 8), Text('Lat: ${_pickedLocation!.latitude.toStringAsFixed(5)}\nLng: ${_pickedLocation!.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 13))])),
              const SizedBox(height: 8),
              _isDetectingLocation
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _isSaving ? null : _detectLocation, icon: const Icon(Icons.my_location), label: Text(_pickedLocation == null ? 'Detect My Location (GPS)' : 'Re-detect Location'))),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _isSaving ? null : _openMapPicker, icon: const Icon(Icons.map), label: const Text('Select Location on Map'))),
              const SizedBox(height: 24),

              if (_error != null)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)), child: Text(_error!, style: TextStyle(color: Colors.red[700])))),

              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _savePlace,
                  icon: _isSaving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_location_alt),
                  label: Text(_isSaving ? _uploadedCount == 0 ? 'Saving place…' : 'Uploading images ($_uploadedCount/${_selectedImages.length})…' : _isEditing ? 'Save Changes' : 'Add Place', style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
