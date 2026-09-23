import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    var onImagePicked: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                // Scale down aggressively to ensure lowest possible file size for avatars
                // Avatars render at max 52x52, so 256x256 is perfectly crisp on @3x Retina displays
                let maxDimension: CGFloat = 256
                var finalImage = image
                if image.size.width > maxDimension || image.size.height > maxDimension {
                    let ratio = min(maxDimension / image.size.width, maxDimension / image.size.height)
                    let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                    if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                        finalImage = resized
                    }
                    UIGraphicsEndImageContext()
                }
                
                if let data = finalImage.jpegData(compressionQuality: 0.6) {
                    parent.onImagePicked(data)
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
