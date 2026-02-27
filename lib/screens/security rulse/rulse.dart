 // ============ SECURITY RULES RECOMMENDATIONS ============
  
  /*
  Firestore Security Rules should match this structure:
  
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      // Allow users to read their own data
      match /users/{userId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Church data - users can only access their church's data
      match /churches/{churchId} {
        allow read: if request.auth != null && 
          get(/databases/$(database)/documents/users/$(request.auth.uid)).data.churchId == churchId;
        allow write: if request.auth != null && 
          get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'pastor'];
        
        match /{document=**} {
          allow read: if request.auth != null && 
            get(/databases/$(database)/documents/users/$(request.auth.uid)).data.churchId == churchId;
          allow write: if request.auth != null && 
            get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'pastor'];
        }
      }
    }
  }
  */