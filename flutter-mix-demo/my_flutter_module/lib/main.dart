import 'package:flutter/material.dart';
import 'diweb_channel.dart';

void main() => runApp(const MyFlutterApp());

class MyFlutterApp extends StatelessWidget {
  const MyFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '发现',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DiscoverPage(),
    );
  }
}

/// 发现 Tab - Flutter 页面
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('发现'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBanner(),
          const SizedBox(height: 16),
          const Text(
            '推荐内容',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFeedItem('车主社区热帖', '分享你的用车心得', Icons.forum_outlined),
          _buildFeedItem('最新活动', '限时保养优惠进行中', Icons.local_offer_outlined),
          _buildFeedItem('用车攻略', '冬季出行注意事项', Icons.menu_book_outlined),
          const SizedBox(height: 16),
          _buildFeedItem(
            '查看 H5 详情',
            '从 Flutter 打开原生 H5 二级页',
            Icons.language_outlined,
            onTap: () => DIWebChannel.openH5('diweb/demo.html', title: 'H5 详情'),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '发现精彩',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Flutter 混合渲染 · HarmonyOS 原生 Tab',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedItem(String title, String subtitle, IconData icon, {VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF007AFF)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
