import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../main.dart';class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // Attendance state: 'not_logged_in', 'working', 'on_break', 'logged_out'
  String _state = 'not_logged_in';
  String? _signinTime;
  int _totalBreak = 0;
  bool _limitReached = false;
  bool _loadingStatus = true;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() => _loadingStatus = true);
    final result = await ApiService.getStatus();
    if (!mounted) return;
    setState(() {
      _state = result['state'] ?? 'not_logged_in';
      _signinTime = result['signin_time'];
      _totalBreak = result['total_break'] ?? 0;
      _limitReached = result['limit_reached'] ?? false;
      _loadingStatus = false;
    });
  }

  Future<Position?> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Please enable location services');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMessage('Location permission denied');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showMessage('Location permission permanently denied — enable it from settings');
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onCheckIn() async {
    setState(() => _actionInProgress = true);
    final position = await _getLocation();
    if (!mounted) return;

    final result = await ApiService.clockIn(
      lat: position?.latitude,
      lng: position?.longitude,
    );
    if (!mounted) return;

    setState(() => _actionInProgress = false);
    _showMessage(result['msg'] ?? 'Check-in attempted');
    if (result['status'] == 'success') _fetchStatus();
  }

  Future<void> _onCheckOut() async {
    setState(() => _actionInProgress = true);
    final result = await ApiService.clockOut();
    if (!mounted) return;

    setState(() => _actionInProgress = false);
    _showMessage(result['msg'] ?? 'Check-out attempted');
    if (result['status'] == 'success') _fetchStatus();
  }

  Future<void> _onOutBreak() async {
    setState(() => _actionInProgress = true);
    final result = await ApiService.breakOut();
    if (!mounted) return;

    setState(() => _actionInProgress = false);
    _showMessage(result['msg'] ?? 'Break start attempted');
    if (result['status'] == 'success') _fetchStatus();
  }

  Future<void> _onInBack() async {
    setState(() => _actionInProgress = true);
    final result = await ApiService.breakIn();
    if (!mounted) return;

    setState(() => _actionInProgress = false);
    _showMessage(result['msg'] ?? 'Break end attempted');
    if (result['status'] == 'success') _fetchStatus();
  }

  Future<void> _onLogout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchStatus,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'HR Baqira Technology',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, size: 20),
                      onPressed: _onLogout,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAttendanceCard(),
                const SizedBox(height: 16),
                _buildStatsGrid(),
                const SizedBox(height: 16),
                _buildOngoingProjectsCard(),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildToDoListCard()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNoticeBoardCard()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ---------- Today's Attendance ----------
  Widget _buildAttendanceCard() {
    final bool isWorking = _state == 'working';
    final bool isOnBreak = _state == 'on_break';
    final bool isLoggedOut = _state == 'logged_out';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Attendance",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_loadingStatus)
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  isWorking
                      ? 'Working'
                      : isOnBreak
                      ? 'On Break'
                      : isLoggedOut
                      ? 'Completed'
                      : 'Not logged in',
                  style: TextStyle(
                    color: isWorking
                        ? Colors.green
                        : isOnBreak
                        ? Colors.orange
                        : Colors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _attendanceButton(
                  label: 'Check In',
                  color: const Color(0xFF34B857),
                  onTap: (_actionInProgress || isWorking || isOnBreak || isLoggedOut)
                      ? null
                      : _onCheckIn,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _attendanceButton(
                  label: 'Check Out',
                  color: const Color(0xFFE9455A),
                  onTap: (_actionInProgress || !(isWorking || isOnBreak)) ? null : _onCheckOut,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _attendanceButton(
                  label: 'Out (Break)',
                  color: const Color(0xFFF4B740),
                  onTap: (_actionInProgress || !isWorking || _limitReached) ? null : _onOutBreak,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _attendanceButton(
                  label: 'In (Back)',
                  color: const Color(0xFF17B6A7),
                  onTap: (_actionInProgress || !isOnBreak) ? null : _onInBack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _signinTime != null ? 'Logged in: $_signinTime' : 'Not checked in yet',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              if (_limitReached)
                const Text(
                  'Break limit reached',
                  style: TextStyle(
                      color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attendanceButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  // ---------- Stats grid (static placeholder — apni dashboard API se yahan replace karna) ----------
  Widget _buildStatsGrid() {
    final stats = [
      _StatItem('15', 'Employees', const Color(0xFF3B7DED), isSolid: false),
      _StatItem('5', 'Leaves', const Color(0xFF17B6A7), isSolid: false),
      _StatItem('0', 'Projects', const Color(0xFFE9455A), isSolid: false),
      _StatItem('7', 'Ex-employees', const Color(0xFF2F62D6), isSolid: true),
      _StatItem('5', 'Leave Apps', const Color(0xFF17B6A7), isSolid: true),
      _StatItem('0', 'Completed', const Color(0xFFE9455A), isSolid: true),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) => _buildStatCard(stats[index]),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    if (item.isSolid) {
      return Container(
        decoration: BoxDecoration(
          color: item.color,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: _cardDecoration(),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 14, backgroundColor: item.color),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ---------- Ongoing Projects ----------
  Widget _buildOngoingProjectsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Ongoing Projects',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text('View all', style: TextStyle(color: Colors.blue, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: const [
                Text('No ongoing projects', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  'Projects assigned to you will appear here.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- To-do list ----------
  Widget _buildToDoListCard() {
    final tasks = ['Update employee data', 'Review leave request', 'Call client', 'Prepare report'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('To-do list', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text('${tasks.length} tasks', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 10),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(task, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Notice board ----------
  Widget _buildNoticeBoardCard() {
    final notices = [
      _Notice('Independence Day', '15 Aug'),
      _Notice('Language Day', '21 Feb'),
      _Notice('Aids Day', '1 Dec'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notice Board', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const Text('Latest updates', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 10),
          for (final notice in notices)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(notice.date, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Bottom nav ----------
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Attendance'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Shifts'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Employees'),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class _StatItem {
  final String value;
  final String label;
  final Color color;
  final bool isSolid;

  _StatItem(this.value, this.label, this.color, {required this.isSolid});
}

class _Notice {
  final String title;
  final String date;

  _Notice(this.title, this.date);
}