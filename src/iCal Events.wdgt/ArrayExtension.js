// ArrayExtension.js
// Copyright 2007 Ben Kazez
// Adds handy capabilities to Array.
//

/* Removes all occurrences of obj
 */
Array.prototype.removeAll = function(obj) {
	var newArr = new Array();
	var len = this.length;
	for(var i = 0; i < len; i++) {
		if(this[i] != obj)
			newArr.push(this[i]);
	}
	this = newArr;
	return this;
}

/* Removes element at the given index
 */
Array.prototype.remove = function(index) {
	return this.splice(index, 1);
}