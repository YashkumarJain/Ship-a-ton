import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/assistant_response.dart';
import '../models/dashboard_data.dart';
import '../models/financial_goal.dart';
import '../models/news_item.dart';
import '../models/profile.dart';
import '../models/statement_import.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiService {
  String? get _token {
    if (!AppConfig.supabaseConfigured) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        '${body['error'] ?? 'Request failed'}',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<UserProfile> profile() async {
    final response = await http.get(_uri('/api/profile'), headers: _headers);
    return UserProfile.fromJson(await _decode(response));
  }

  Future<UserProfile> saveProfile({
    required String displayName,
    int? age,
    double? monthlyBudget,
    double? savingsBalance,
  }) async {
    final response = await http.put(
      _uri('/api/profile'),
      headers: _headers,
      body: jsonEncode({
        'displayName': displayName,
        if (age != null) 'age': age,
        if (monthlyBudget != null) 'monthlyBudget': monthlyBudget,
        if (savingsBalance != null) 'savingsBalance': savingsBalance,
      }),
    );
    return UserProfile.fromJson(await _decode(response));
  }

  Future<DashboardData> dashboard() async {
    final response = await http.get(_uri('/api/dashboard'), headers: _headers);
    return DashboardData.fromJson(await _decode(response));
  }

  Future<StatementImportResult> parseStatement({
    required Uint8List bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/statements/parse'));
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(http.MultipartFile.fromBytes(
      'statement',
      bytes,
      filename: filename,
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return StatementImportResult.fromJson(await _decode(response));
  }

  Future<Map<String, dynamic>> commitStatement(
    List<StatementTransaction> transactions,
  ) async {
    final response = await http.post(
      _uri('/api/statements/commit'),
      headers: _headers,
      body: jsonEncode({
        'approved': true,
        'transactions': transactions.map((item) => item.toJson()).toList(),
      }),
    );
    return _decode(response);
  }

  Future<AssistantResponse> chat(
    String message, {
    Map<String, dynamic>? goalContext,
  }) async {
    final response = await http.post(
      _uri('/api/ai/chat'),
      headers: _headers,
      body: jsonEncode({
        'message': message,
        if (goalContext != null) 'goalContext': goalContext,
      }),
    );
    return AssistantResponse.fromJson(await _decode(response));
  }

  Future<Map<String, dynamic>> applyGoalProposal(GoalProposal proposal) async {
    final response = await http.post(
      _uri('/api/goals/apply-proposal'),
      headers: _headers,
      body: jsonEncode(proposal.approvedPayload()),
    );
    return _decode(response);
  }

  Future<List<FinancialGoal>> goals() async {
    final response = await http.get(_uri('/api/goals'), headers: _headers);
    final payload = await _decode(response);
    return ((payload['goals'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => FinancialGoal.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<FinancialGoal> createGoal({
    required String name,
    required String goalType,
    required double targetAmount,
    String? targetDate,
  }) async {
    final response = await http.post(
      _uri('/api/goals'),
      headers: _headers,
      body: jsonEncode({
        'approved': true,
        'name': name,
        'goalType': goalType,
        'targetAmount': targetAmount,
        if (targetDate != null && targetDate.isNotEmpty) 'targetDate': targetDate,
      }),
    );
    final payload = await _decode(response);
    return FinancialGoal.fromJson(Map<String, dynamic>.from(payload['goal'] as Map));
  }

  Future<FinancialGoal> updateGoal(FinancialGoal goal) async {
    final response = await http.put(
      _uri('/api/goals/${goal.id}'),
      headers: _headers,
      body: jsonEncode({
        'approved': true,
        'name': goal.name,
        'goalType': goal.goalType,
        'targetAmount': goal.targetAmount,
        if (goal.targetDate != null) 'targetDate': goal.targetDate,
      }),
    );
    final payload = await _decode(response);
    return FinancialGoal.fromJson(Map<String, dynamic>.from(payload['goal'] as Map));
  }

  Future<void> deleteGoal(String id) async {
    final response = await http.delete(
      _uri('/api/goals/$id', {'approved': 'true'}),
      headers: _headers,
    );
    await _decode(response);
  }

  Future<Map<String, dynamic>> subscriptionStatus() async {
    final response = await http.get(
      _uri('/api/subscription/status'),
      headers: _headers,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> simulatePremium() async {
    final response = await http.post(
      _uri('/api/subscription/simulate'),
      headers: _headers,
      body: jsonEncode({'active': true}),
    );
    return _decode(response);
  }

  Future<List<NewsItem>> topNews({bool refresh = false}) async {
    final response = await http.get(
      _uri('/api/news/top', {'refresh': '$refresh'}),
      headers: _headers,
    );
    final payload = await _decode(response);
    return ((payload['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => NewsItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> seedDemoData() async {
    final response = await http.post(_uri('/api/demo/seed'), headers: _headers);
    await _decode(response);
  }
}
