import 'dart:convert';
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key, required this.MyCoordinate}) : super(key: key);
  final LatLng MyCoordinate;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  var c = LocationService();
  late GoogleMapController mapController;
  var _panelC = PanelController();
  var _searchPlace = TextEditingController();

  late CameraPosition _initialCameraPosition;
  dynamic places;
  int? selectedPlacesId;
  dynamic selectedPlace;

  Marker? placeMarker; //not used

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initMyLocation();
  }

  @override
  void dispose() {
    super.dispose();
    mapController.dispose();
  }

  // handler to get my location on init map
  initMyLocation() {
    _initialCameraPosition = CameraPosition(
      target: widget.MyCoordinate,
      zoom: 18,
      tilt: 0.0,
    );
  }

  // FAB Button move camera to my location
  _handleToMyLocation() async {
    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: await c.getMyLocation(),
          zoom: 18,
          tilt: 0.0,
        ),
      ),
    );
  }

  // main search function handler
  _handleGoToPlace() async {
    var place = await c.getPlace(input: _searchPlace.text);
    _goToPlace(place);
    await _searchNearby(place);
    setState(() {});
    FocusScope.of(context).unfocus();
    if (_panelC.isPanelClosed) _panelC.open();
  }

  // handler search nearby places by inputing LatLng, this function will join _handleGoToPlace() / main search function
  _searchNearby(place) async {
    places = await c.searchNearby(
      lat: place['geometry']['location']['lat'],
      lng: place['geometry']['location']['lng'],
    );
  }

  // function to move camera to place
  _goToPlace(place) {
    double lat = place['geometry']['location']['lat'];
    double lng = place['geometry']['location']['lng'];

    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lng),
          zoom: 17,
          tilt: 0,
        ),
      ),
    );
  }

  // add marker but not used
  _addMarker(selectedPlace) {
    placeMarker = Marker(
      markerId: MarkerId('Selected Place'),
      infoWindow: InfoWindow(title: '${selectedPlace['name']}'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      position: LatLng(
        selectedPlace['geometry']['location']['lat'],
        selectedPlace['geometry']['location']['lng'],
      ),
    );
  }

  // function to select place in nearby places list in sliding_up_panel
  _chooseLocation() async {
    selectedPlace = await places[selectedPlacesId];
    await _panelC.animatePanelToSnapPoint();
    customModal();
    setState(() {});
  }

  // modal that will return/show selected place so you can do whatever you want with the selected data
  customModal() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(12),
        ),
      ),
      builder: (context) {
        return Wrap(
          children: [
            Column(
              children: [
                _buildSelectedPlaceTile(selectedPlace),
                Container(
                  height: 48,
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        floatingActionButton: _buildCustomFab(),
        appBar: _buildAppBar(),
        body: SlidingUpPanel(
          controller: _panelC,
          minHeight: 0,
          maxHeight: 360,
          panelSnapping: true,
          snapPoint: 0.1,
          color: Colors.white,
          parallaxEnabled: true,
          parallaxOffset: 0.5,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16),
          ),
          panelBuilder: (controller) {
            return _buildPanel(controller);
          },
          body: _buildMap(),
        ),
      ),
    );
  }

  // just AppBar to search place
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0.5,
      title: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchPlace,
                autofocus: false,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.87),
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  hintText: 'Search Place',
                  hintStyle: TextStyle(
                    color: Colors.black.withOpacity(0.67),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            SizedBox(width: 24),
            IconButton(
              constraints: BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: () {
                _handleGoToPlace();
              },
              icon: Icon(
                Icons.search_rounded,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // custom floating action button to go to my location
  FloatingActionButton _buildCustomFab() {
    return FloatingActionButton(
      backgroundColor: Colors.white70,
      onPressed: () {
        _handleToMyLocation();
      },
      child: Icon(
        Icons.my_location,
        color: Colors.black87,
      ),
    );
  }

  // google maps screen
  Widget _buildMap() {
    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: _initialCameraPosition,
      onMapCreated: (controller) => mapController = controller,
      // markers: {
      //   if (placeMarker != null) placeMarker!,
      // },
    );
  }

  // sliding_up_panel panel content
  Widget _buildPanel(controller) {
    if (places != null) {
      return Column(
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(0, 16, 0, 16),
            width: 30,
            height: 5,
            decoration: ShapeDecoration(
              color: Colors.blue,
              shape: StadiumBorder(),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: [
                for (var i = 0; i < places.length; i++)
                  _buildNearbyPlacesTile(i),
              ],
            ),
          ),
          Container(
            height: 48,
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                _chooseLocation();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
              ),
              child: Text(
                'Choose Location',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16),
              ),
            ),
          ),
        ],
      );
    } else {
      return Container();
    }
  }

  // nearby place tile in sliding_up_panel
  Widget _buildNearbyPlacesTile(i) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          selectedPlacesId = i;
          setState(() {});
        },
        child: Container(
          color: selectedPlacesId == i ? Colors.blue : Colors.transparent,
          padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // nama
              Text(
                places[i]['name'] ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selectedPlacesId == i ? Colors.white : Colors.black,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 4),

              // alamat
              Text(
                places[i]['vicinity'] ?? '',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  color: selectedPlacesId == i ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // selected place tile in modalBottomSheet
  Widget _buildSelectedPlaceTile(place) {
    return InkWell(
      onTap: () {},
      child: Container(
        margin: EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: Row(
          children: [
            // Detail
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // nama
                  Text(
                    place['name'] ?? 'Store Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 12),

                  // status buka
                  Row(
                    children: [
                      Icon(
                        Icons.watch_later_outlined,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        place['business_status'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // alamat
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place['vicinity'] ?? 'Location',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ MAP SERVICE ============
class LocationService {
// ============ geolocator Service ============

// calling permission request to use location with permission_handler
  getPermission() async {
    PermissionStatus permissionGranted;
    return permissionGranted = await Permission.location.request();
  }

  // get my location latitude longitude and return the function LatLng
  getMyLocation() async {
    var _geolocatorPlatform = await GeolocatorPlatform.instance;
    var position = await _geolocatorPlatform.getCurrentPosition();

    return LatLng(position.latitude, position.longitude);
  }

// ============================================

// ============ Google Maps Api Service ============

  String apiKey = 'YOUR_API_KEY';

  // get place id by inputing place name in the url by get method this will return place id
  Future getPlaceId(String input) async {
    var url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$input&inputtype=textquery&key=$apiKey');

    var response = await http.get(url);
    var json = jsonDecode(response.body);
    var placeId = json['candidates'][0]['place_id'] as String;
    return placeId;
  }

  // get place detail by inputing place id in the url by get method from getPlaceId function, this will return single place data
  Future getPlace({input}) async {
    var placeId = await getPlaceId(input);
    var url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey');
    var response = await http.get(url);
    var json = jsonDecode(response.body);
    var result = json['result'] as Map<String, dynamic>;
    searchNearby(
      lat: result['geometry']['location']['lat'],
      lng: result['geometry']['location']['lng'],
    );

    return result;
  }

  // search nearby place by inputing LatLng place from getPlace in nearbysearch url, this will return nearby places data list
  Future searchNearby({
    keyword = '',
    lat,
    lng,
    // int radius = 10,
  }) async {
    String rankOrRadius = 'rankby=distance';
    // if (rankOrRadius == 10) {
    //   rankOrRadius = 'radius=$radius';
    // }

    // if keyword is not null, the function will get single place data from api if it's null just LatLng it will return places list
    if (keyword != null) {
      keyword = 'keyword=${keyword}&';
    }
    var url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?${keyword}location=${lat}%2C${lng}&${rankOrRadius}&key=${apiKey}');

    var response = await http.get(url);
    var json = jsonDecode(response.body);
    var nearbyPlaces = json['results'];

    return nearbyPlaces;
  }

  // NOT USED, NO API PERMISION FOR DIRECTION

  // Future getDirection(String origin, String destination) async {
  //   var url = Uri.parse(
  //       'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$apiKey');
  //   var response = await http.get(url);
  //   var json = jsonDecode(response.body);
  // }

  // ============================================

}

// on app start loading screen to get permission for using location and getting my location
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  var c = LocationService();

  // if permission is granted/accepted for using location it will go to the map screen if it's not the app will close
  handlerMapLocation() {
    c.getPermission().then((permissionGranted) async {
      if (permissionGranted == PermissionStatus.granted) {
        LatLng myCoordinate = await c.getMyLocation();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MapScreen(
              MyCoordinate: myCoordinate,
            ),
          ),
        );
      } else {
        SystemNavigator.pop();
      }
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    handlerMapLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text(
              'Looking for your location ...',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
