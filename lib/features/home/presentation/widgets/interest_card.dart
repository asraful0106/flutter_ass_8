import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InterestCard extends StatelessWidget {
  const InterestCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.description,
    this.onViewMore,
  });

  final String imageUrl;
  final String title;
  final String description;
  final VoidCallback? onViewMore;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      clipBehavior:
          Clip.antiAlias, // clips the image to the card's rounded corners
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          Container(
            padding: EdgeInsets.all(5.w),
            height: 140.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6.r),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image,
                    size: 32.w,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.h),

                // Description
                Text(
                  description,
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12.h),

                // View button
              Center(
                child: FilledButton(
                    onPressed: onViewMore ?? () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color.fromARGB(38, 179, 179, 179),
                      padding: EdgeInsets.symmetric(horizontal: 30.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.w),
                      ),
                    ),
                    child: Text(
                      "View More",
                      style: TextStyle(fontSize: 16.sp, color: Colors.blue),
                    ),
                  ),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
