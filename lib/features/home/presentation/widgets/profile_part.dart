import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfilePart extends StatefulWidget {
  const ProfilePart({super.key});

  @override
  State<ProfilePart> createState() => _ProfilePartState();
}

class _ProfilePartState extends State<ProfilePart> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 15.h),
              // Circular Profile photo
              CircleAvatar(
                radius: 80,
                backgroundImage: NetworkImage(
                  "https://images.unsplash.com/photo-1529665253569-6d01c0eaf7b6?q=80&w=1085&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=NHwxMjA3fDA%3D",
                ),
              ),
              SizedBox(height: 16.h),
              // Name
              Text(
                "John Doe",
                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              // Title
              Text(
                "Flutter Developer",
                style: TextStyle(
                  fontSize: 18.sp,
                  color: const Color.fromARGB(141, 97, 97, 97),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              // Description
              Text(
                "Passionate about creating user-friendly and engaging digital experiences",
                style: TextStyle(fontSize: 14.sp),
                textAlign: TextAlign.center,
              ),
              Container(
                width: double.infinity,
                height: 2.h,
                color: Color.fromARGB(28, 167, 167, 167),
                margin: EdgeInsets.symmetric(vertical: 10.h),
              ),
              // Email
              Row(
                spacing: 8.w,
                children: [Icon(Icons.email), Text("john.doe@example.com")],
              ),
              SizedBox(height: 8.h),
              // Phoen
              Row(
                spacing: 4.w,
                children: [Icon(Icons.phone), Text("+1234567890")],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 10.w,
                children: [
                  // Follow button
                  FilledButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        const Color(0xff016CD7),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.w),
                        ),
                      ),
                    ),
                    onPressed: () => {},
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 30.w),
                      child: Text("Follow", style: TextStyle(fontSize: 16.sp),),
                    ),
                  ),
                  // Messege butto
                  FilledButton(
                    style: ButtonStyle(
                      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.w),
                          side: BorderSide(width: 1.w, color: const Color.fromARGB(69, 88, 87, 87)),
                        ),
                      ),
                    ),
                    onPressed: () => {},
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 30.w),
                      child: Text(
                        "Message",
                        style: TextStyle(fontSize: 16.sp, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
