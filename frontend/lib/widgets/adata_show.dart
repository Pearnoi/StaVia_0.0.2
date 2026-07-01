import 'package:flutter/material.dart';

class AdataCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String cardType; 
  
  const AdataCard({super.key, required this.data, this.cardType = 'upload', });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success header
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '$cardType Successful',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            
            // AnnData Info
            if (data['adata_info'] != null) ...[
              const Text(
                'AnnData Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Dimensions: ${data['adata_info']['dimensions']}'),
              Text('Observations: ${data['adata_info']['obs_keys']?.join(', ') ?? 'N/A'}'),
              Text('Variables: ${data['adata_info']['var_keys']?.join(', ') ?? 'N/A'}'),
            ],
            
            const SizedBox(height: 12),
            
            // Analyses
            if (data['analyses'] != null && data['analyses'].isNotEmpty && cardType == 'Upload') ...[
              const Text(
                'Detected Analyses',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(data['analyses'].join(', ')),
            ],
            
            const SizedBox(height: 12),
            
            // Files
            if (data['files'] != null && data['files'].isNotEmpty && cardType == 'Upload') ...[
              const Text(
                'Files',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              ...data['files'].take(5).map((file) => 
                Text('• $file', style: const TextStyle(fontSize: 13)),
              ),
              if (data['files'].length > 5)
                Text('... and ${data['files'].length - 5} more'),
            ],
          ],
        ),
      ),
    );
  }
}