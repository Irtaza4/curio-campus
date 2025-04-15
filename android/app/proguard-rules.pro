# Preserve annotations used by libraries like Jackson
-keepattributes *Annotation*

# Keep Jackson classes and prevent them from being removed or obfuscated
-keepclassmembers class * {
    @com.fasterxml.jackson.annotation.* <fields>;
    @com.fasterxml.jackson.annotation.* <methods>;
}
-keep class com.fasterxml.jackson.databind.** { *; }
-keep class com.fasterxml.jackson.core.** { *; }
-dontwarn com.fasterxml.jackson.databind.ext.**

# Prevent R8 from removing or warning about Java Beans classes
-keep class java.beans.** { *; }
-dontwarn java.beans.**

# Prevent R8 from removing or warning about DOM XML classes
-keep class org.w3c.dom.bootstrap.DOMImplementationRegistry { *; }
-dontwarn org.w3c.dom.bootstrap.**
